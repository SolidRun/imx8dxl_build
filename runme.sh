#!/bin/bash

### Options
: ${CROSS_COMPILE:=aarch64-linux-gnu-}
: ${SOC_REVISION:=A0}
: ${IMAGE_SIZE_MiB:=1000}
: ${GATEWAY_REVISION:=1.1}
: ${SOM_REVISION:=2.1}

### Versions
ATF_GIT_URI=https://github.com/nxp-imx/imx-atf
ATF_RELEASE=tags/lf-5.15.71-2.2.2
UBOOT_GIT_URI=https://github.com/nxp-imx/uboot-imx
UBOOT_RELEASE=tags/lf-5.15.71-2.2.2
MKIMAGE_GIT_URI=https://github.com/nxp-imx/imx-mkimage
MKIMAGE_RELEASE=tags/lf-5.15.71-2.2.2
SECO_HTTP_URI=https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/imx-seco-5.9.0.bin
SECO_RELEASE=5.9.0
SCFW_FILE=IMX-SCFW-PORTING-KIT-1.15.0.tar.gz
SCFW_FILE_URI="https://www.nxp.com/webapp/Download?colCode=L6.1.22_2.0.0_SCFWKIT-1.15.0&appType=license"
SCFW_RELEASE=1.15.0
LINUX_GIT_URI=https://github.com/nxp-imx/linux-imx
LINUX_RELEASE=lf-5.15.71-2.2.2
SAFSDIO_FILE=saf-sdio_RFP1.0.4.tgz
SAFSDIO_FILE_URI="NXP SAF5400 BSP v0.15 (linux-roadlink_evk2.0-v0.15.tgz:bsp/v2x-src/saf5x00)"
LLC_FILE=llc_RFP2.5.tgz
LLC_FILE_URI="NXP SAF5400 BSP v0.15 (linux-roadlink_evk2.0-v0.15.tgz:bsp/v2x-src/saf5x00)"

###

ROOTDIR=`pwd`

COMPONENTS="atf uboot mkimage seco scfw linux safsdio llc"
mkdir -p build
dlfailed=0
for i in $COMPONENTS; do
	if [[ ! -d ${ROOTDIR}/build/$i ]]; then
		GIT_URI_VAR=${i^^}_GIT_URI
		RELEASE_VAR=${i^^}_RELEASE
		HTTP_URI_VAR=${i^^}_HTTP_URI
		FILE_VAR=${i^^}_FILE
		FILE_URI_VAR=${i^^}_FILE_URI

		if [[ -n ${!GIT_URI_VAR} ]]; then
			echo "Fetching $i from Git ..."
			git clone "${!GIT_URI_VAR}" "${ROOTDIR}/build/$i"

			if [ $? -ne 0 ]; then
				echo "Warning: Failed to fetch $i!"
				dlfailed=1
				continue
			elif [[ -n ${!RELEASE_VAR} ]]; then
				cd "${ROOTDIR}/build/$i"
				git checkout "${!RELEASE_VAR}"

				if [ $? -ne 0 ]; then
					echo "Warning: Failed to checkout $i release ${!RELEASE_VAR}!"
					dlfailed=1
					continue
				fi
			fi
		fi

		if [[ -n ${!HTTP_URI_VAR} ]]; then
			mkdir "${ROOTDIR}/build/$i"
			cd "${ROOTDIR}/build/$i"

			wget "${!HTTP_URI_VAR}"
			if [ $? -ne 0 ]; then
				echo "Warning: Failed to fetch $i!"
				cd "${ROOTDIR}"
				rm -rf "${ROOTDIR}/build/$i"
				dlfailed=1
				continue
			fi
		fi

		if [[ -n ${!FILE_VAR} ]]; then
			if [[ -f ${ROOTDIR}/${!FILE_VAR} ]]; then
				if [[ ${!FILE_VAR} =~ \.tgz$ ]]; then
					tar -C "${ROOTDIR}/build" -xf "${ROOTDIR}/${!FILE_VAR}"

					if [ $? -ne 0 ]; then
						echo "Error: Failed to unpack \"${!FILE_VAR}\"!"
					fi

					if [[ $i == safsdio ]]; then
						mv "${ROOTDIR}/build/saf-sdio" "${ROOTDIR}/build/safsdio"
					fi
				else
					mkdir "${ROOTDIR}/build/$i"
					cp -v "${ROOTDIR}/${!FILE_VAR}" "${ROOTDIR}/build/$i/"
				fi
			else
				echo "Warning: Missing file ${!FILE_VAR}! Please download manually and place it next to this script."

				if [[ -n ${!FILE_URI_VAR} ]]; then
					echo "${!FILE_URI_VAR}"
				fi

				dlfailed=1
				continue
			fi
		fi

		# post-download processing
		cd "${ROOTDIR}/build/$i/"

		# scfw porting kit is multi-wrapped :(
		if [[ $i == scfw ]]; then
			tar --wildcards --strip-components=2 -xvf $SCFW_FILE "*.bin"

			if [ $? -ne 0 ]; then
				echo "Warning: Failed to extract scfw porting kit layer 1!"
				dlfailed=1
				cd "${ROOTDIR}"
				rm -rf "${ROOTDIR}/build/$i"
				continue
			fi
		fi

		# unpack NXP PKGs
		for NXPPKG in `ls *.bin 2>/dev/null`; do
			chmod +x $NXPPKG
			./$NXPPKG --auto-accept

			if [ $? -ne 0 ]; then
				echo "Warning: Failed to extract $NXPPKG!"
				dlfailed=1
				cd "${ROOTDIR}"
				rm -rf "${ROOTDIR}/build/$i"
				continue
			fi
		done

		# scfw porting kit is multi-wrapped :(
		if [[ $i == scfw ]]; then
			find imx-scfw-porting-kit-${SCFW_RELEASE} -iname "scfw_export_mx8*.gz" -exec tar --strip-components 1 --one-top-level=scfw_export_mx8 -xzf {} \;
			if [ $? -ne 0 ] || [[ ! -d scfw_export_mx8 ]]; then
				echo "Warning: Failed to extract scfw porting kit layer 3!"
				dlfailed=1
				cd "${ROOTDIR}"
				rm -rf "${ROOTDIR}/build/$i"
				continue
			fi
		fi

		if [[ -d ${ROOTDIR}/patches/$i ]]; then
			for patch in "${ROOTDIR}/patches/$i"/*; do
				echo "Applying $patch ..."
				test -e .git && git am "$patch"
				test -e .git || patch -p1 < $patch

				if [ $? -ne 0 ]; then
					echo "Warning: Failed to apply $patch!"
					dlfailed=1
					break
				fi
			done
		fi
	fi
done

# Particular tools
mkdir -p "${ROOTDIR}/tools"
cd "${ROOTDIR}/tools"

if [ ! -e gcc-arm-none-eabi-8-2018-q4-major-linux.tar.bz2 ]; then
	wget https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/8-2018q4/gcc-arm-none-eabi-8-2018-q4-major-linux.tar.bz2
	if [ $? -ne 0 ]; then
		dlfailed=1
	fi
fi

if [ ! -d gcc-arm-none-eabi-8-2018-q4-major ] && [ -f gcc-arm-none-eabi-8-2018-q4-major-linux.tar.bz2 ]; then
	tar -xf gcc-arm-none-eabi-8-2018-q4-major-linux.tar.bz2
	if [ $? -ne 0 ]; then
		echo "Warning: Failed to unpack arm embedded cross toolchain!"
		dlfailed=1
	fi
fi

if [ $dlfailed -ne 0 ]; then
	echo "Some downloads failed, aborting build."
	exit 1
fi

### Compile
set -eu
set -o pipefail

# Copy SECO FW
case ${SOC_REVISION,,} in
	a0)
		# seco knows a0 as a1.
		SECO_R=a1
	;;
	*)
		SECO_R=${SOC_REVISION,,}
	;;
esac
cd "${ROOTDIR}/build/seco"
cp -v imx-seco-${SECO_RELEASE}/firmware/seco/mx8dxl${SECO_R}-ahab-container.img "${ROOTDIR}/build/mkimage/iMX8DXL/"
cp -v imx-seco-${SECO_RELEASE}/firmware/seco/mx8dxl${SECO_R}-ahab-container.img "${ROOTDIR}/build/uboot/ahab-container.img"

# Build SCFW
case ${SOC_REVISION,,} in
	b0)
		# B0 currently has no specific SCU Firmware variant, reuse A0.
		SCFW_R=A0
	;;
	*)
		SCFW_R=${SOC_REVISION^^}
	;;
esac
cd "${ROOTDIR}/build/scfw/scfw_export_mx8"
make TOOLS="${ROOTDIR}/tools" R=${SCFW_R^^} B=evk D=0 M=0 dxl
cp -v build_mx8dxl_${SCFW_R,,}/scfw_tcm.bin "${ROOTDIR}/build/uboot/mx8dxl-sr-som-scfw-tcm.bin"
cp -v build_mx8dxl_${SCFW_R,,}/scfw_tcm.bin "${ROOTDIR}/build/mkimage/iMX8DXL/"
mkdir -p ${ROOTDIR}/images
cp -v build_mx8dxl_${SCFW_R,,}/scfw_tcm.bin "${ROOTDIR}/images/mx8dxl-sr-som-scfw-tcm.bin"

# Build ATF
cd "${ROOTDIR}/build/atf"
make -j$(nproc) CROSS_COMPILE="$CROSS_COMPILE" PLAT=imx8dxl bl31
cp -v build/imx8dxl/release/bl31.bin "${ROOTDIR}/build/mkimage/iMX8DXL/"

# Build u-boot
cd "${ROOTDIR}/build/uboot"
make CROSS_COMPILE="$CROSS_COMPILE" imx8dxl_v2x_defconfig
case "${GATEWAY_REVISION}:${SOM_REVISION}" in
1.0:2.0)
	UBOOT_DEFAULT_FDT_FILE="imx8dxl-v2x.dtb"
	;;
1.1:2.0|2.0:2.0)
	UBOOT_DEFAULT_FDT_FILE="imx8dxl-v2x-v11.dtb"
	;;
1.1:2.1|2.0:2.1)
	UBOOT_DEFAULT_FDT_FILE="imx8dxl-v2x-v11-som-v21.dtb"
	;;
*)
	echo "Specified invalid combination of gateway revision \"${GATEWAY_REVISION}\" and som revision \"${SOM_REVISION}\"!"
	exit 1
	;;
esac
printf "CONFIG_DEFAULT_FDT_FILE=\"%s\"\n" "${UBOOT_DEFAULT_FDT_FILE}" >> .config
make -j$(nproc) CROSS_COMPILE="$CROSS_COMPILE"
cp -v u-boot.bin "${ROOTDIR}/build/mkimage/iMX8DXL/"

# Assemble bootable image
cd "${ROOTDIR}/build/mkimage"
make SOC=iMX8DXL REV=${SECO_R^^} flash
cp -v "${ROOTDIR}/build/mkimage/iMX8DXL/flash.bin" "${ROOTDIR}/images/uboot.bin"

echo "Finished compiling bootloader image."

# Build Linux
mkdir -p "${ROOTDIR}/build/linux-build"
cd "${ROOTDIR}/build/linux"
find "${ROOTDIR}/configs/linux" -type f | sort | xargs ./scripts/kconfig/merge_config.sh -O "${ROOTDIR}/build/linux-build" -m arch/arm64/configs/imx_v8_defconfig /dev/null
make -C "${ROOTDIR}/build/linux" O="${ROOTDIR}/build/linux-build" ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
cd "${ROOTDIR}/build/linux-build"
#make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" menuconfig
make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" savedefconfig
make -j$(nproc) ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" dtbs Image modules

rm -rf "${ROOTDIR}/images/linux"
mkdir -p "${ROOTDIR}/images/linux/boot/extlinux"
cp -v arch/arm64/boot/dts/freescale/imx8dxl*.dtb "${ROOTDIR}/images/linux/boot/"
cp -v arch/arm64/boot/Image "${ROOTDIR}/images/linux/boot/"
cp -v System.map "${ROOTDIR}/images/linux/boot/"
cp -v .config "${ROOTDIR}/images/linux/boot/config"
make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_PATH="${ROOTDIR}/images/linux/usr" modules_install
KRELEASE=`make kernelrelease`

cat > "${ROOTDIR}/images/linux/boot/extlinux/extlinux.conf" << EOF
label linux
	linux ../Image
	fdtdir ..
	append root=/dev/mmcblk0p1 ro rootwait net.ifnames=0
EOF

# Build external Linux Headers package for compiling modules
cd "${ROOTDIR}/build/linux"
rm -rf "${ROOTDIR}/images/linux-headers"
mkdir -p ${ROOTDIR}/images/linux-headers
tempfile=$(mktemp)
find . -name Makefile\* -o -name Kconfig\* -o -name \*.pl > $tempfile
find arch/arm64/include include scripts -type f >> $tempfile
tar -c -f - -T $tempfile | tar -C "${ROOTDIR}/images/linux-headers" -xf -
cd "${ROOTDIR}/build/linux-build"
find arch/arm64/include .config Module.symvers include scripts -type f > $tempfile
tar -c -f - -T $tempfile | tar -C "${ROOTDIR}/images/linux-headers" -xf -
rm -f $tempfile
unset tempfile
cd "${ROOTDIR}/images/linux-headers"
tar cpf "${ROOTDIR}/images/linux-headers.tar" *


# Build SAF5x00 SDIO Driver
if [[ -d ${ROOTDIR}/build/safsdio ]]; then
	cd "${ROOTDIR}/build/safsdio"

	make -C "${ROOTDIR}/build/linux-build" CROSS_COMPILE="$CROSS_COMPILE" ARCH=arm64 M="$PWD" modules
	install -v -m644 -D saf_sdio.ko "${ROOTDIR}/images/linux/usr/lib/modules/${KRELEASE}/kernel/v2x/saf_sdio.ko"
	install -v -m644 -D include/saf_sdio.h "${ROOTDIR}/images/linux/usr/include/linux/saf_sdio.h"
fi

# Build SAF5x00 LLC Driver
if [[ -d ${ROOTDIR}/build/llc ]]; then
	cd "${ROOTDIR}/build/llc/kernel/drivers/cohda/llc"

	make -C "${ROOTDIR}/build/linux-build" CROSS_COMPILE="$CROSS_COMPILE" ARCH=arm64 M=$PWD BOARD=SRIMX8DXLSOM LLC_DEV_CNT=1 modules
	install -v -m644 -D cw-llc.ko "${ROOTDIR}/images/linux/usr/lib/modules/${KRELEASE}/kernel/v2x/cw-llc.ko"
fi

# regenerate modules dependencies
depmod -b "${ROOTDIR}/images/linux/usr" -F "${ROOTDIR}/build/linux-build/System.map" ${KRELEASE}

# Generate a Debian rootfs
mkdir -p "${ROOTDIR}/build/debian"
cd "${ROOTDIR}/build/debian"
if [ ! -f rootfs.e2.orig ] || [[ ${ROOTDIR}/${BASH_SOURCE[0]} -nt rootfs.e2.orig ]]; then
	rm -f rootfs.e2.orig

	# bootstrap a first-stage rootfs
	rm -rf stage1
	fakeroot debootstrap --variant=minbase \
		--arch=arm64 --components=main,contrib,non-free \
		--foreign \
		--include=apt-transport-https,bluez,busybox,ca-certificates,can-utils,command-not-found,chrony,curl,e2fsprogs,ethtool,fdisk,gpiod,gpsd,gpsd-tools,haveged,i2c-tools,ifupdown,iputils-ping,isc-dhcp-client,iw,initramfs-tools,libiio-utils,libnss-resolve,libpcap0.8,lm-sensors,locales,nano,net-tools,ntpdate,openssh-server,psmisc,python3-gps,python3-serial,rfkill,sudo,systemd-sysv,tio,usbutils,wget,wpasupplicant,xterm,xz-utils \
		bullseye \
		stage1 \
		https://deb.debian.org/debian

	# prepare init-script for second stage inside VM
cat > stage1/stage2.sh << EOF
#!/bin/sh

# run second-stage bootstrap
/debootstrap/debootstrap --second-stage

# mount pseudo-filesystems
mount -vt proc proc /proc
mount -vt sysfs sysfs /sys

# configure dns
cat /proc/net/pnp > /etc/resolv.conf

# set empty root password
passwd -d root

# update command-not-found db
apt-file update
update-command-not-found

# enable optional system services
systemctl enable gpsd

# populate fstab
printf "/dev/root / ext4 defaults 0 1\\n" > /etc/fstab

# enable systemd-networkd and re-configure DNS
systemctl enable systemd-networkd
systemctl enable systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# wipe machine-id (regenerates during first boot)
echo uninitialized > /etc/machine-id

# delete self
rm -f /stage2.sh

# flush disk
sync

# power-off
reboot -f
EOF
	chmod +x stage1/stage2.sh

	# create empty partition image
	dd if=/dev/zero of=rootfs.e2.orig bs=1 count=0 seek=${IMAGE_SIZE_MiB}M

	# create filesystem from first stage
	mkfs.ext2 -L rootfs -E root_owner=0:0 -d stage1 rootfs.e2.orig

	# bootstrap second stage within qemu
	qemu-system-aarch64 \
		-m 1G \
		-M virt \
		-cpu cortex-a57 \
		-smp 1 \
		-netdev user,id=eth0 \
		-device virtio-net-device,netdev=eth0 \
		-drive file=rootfs.e2.orig,if=none,format=raw,id=hd0 \
		-device virtio-blk-device,drive=hd0 \
		-nographic \
		-no-reboot \
		-kernel "${ROOTDIR}/images/linux/boot/Image" \
		-append "console=ttyAMA0 root=/dev/vda rootfstype=ext2 ip=dhcp rw init=/stage2.sh" \


	:

	# convert to ext4
	tune2fs -O extents,uninit_bg,dir_index,has_journal rootfs.e2.orig

	# fix errors
	s=0
	e2fsck -y rootfs.e2.orig || s=$?
	if [ $s -ge 4 ]; then
		echo "Error: Couldn't repair generated rootfs."
		rm -f rootfs.e2.orig
		exit 1
	fi
fi;

# Prepare final rootfs
cp rootfs.e2.orig rootfs.e2

# Add os-version to rootfs
gen_os_version() {
	local TIMESTAMP
	local IMAGE_SOURCE_COMMIT

	IMAGE_BUILD_DATE="$(date +%Y%m%d)"
	IMAGE_SOURCE_COMMIT="unknown"
	if [ -d ${ROOTDIR}/.git ]; then
		IMAGE_SOURCE_COMMIT="$(git -C ${ROOTDIR} rev-parse --short HEAD)"
	fi

	printf "PRETTY_NAME=\"%s\"\n" "Debian GNU/Linux 11 (bullseye) SolidRun Fork for i.MX8DXL"
	printf "NAME=\"%s\"\n" "Debian GNU/Linux (SolidRun)"
	printf "VERSION_ID=\"%s\"\n" "11"
	printf "VERSION=\"%s\"\n" "11 (bullseye)"
	printf "VERSION_CODENAME=%s\n" "bullseye"
	printf "ID=%s\n" "debian"
	printf "HOME_URL=\"%s\"\n" "https://www.solid-run.com/"
	printf "SUPPORT_URL=\"%s\"\n" "https://www.solid-run.com/contact-us/#technical-support"
	printf "BUG_REPORT_URL=\"%s\"\n" "https://www.solid-run.com/contact-us/#technical-support"
	printf "IMAGE_BUILD_DATE=\"%s\"\n" "${IMAGE_BUILD_DATE}"
	printf "IMAGE_SOURCE_COMMIT=\"%s\"\n" "${IMAGE_SOURCE_COMMIT}"

}
gen_os_version > "${ROOTDIR}/build/os-version"
e2cp -G 0 -O 0 -P 644 "${ROOTDIR}/build/os-version" -d "${ROOTDIR}/build/debian/rootfs.e2:/etc"

# Add kernel to rootfs
find "${ROOTDIR}/images/linux" -type f -printf "%P\n" | e2cp -G 0 -O 0 -P 644 -s "${ROOTDIR}/images/linux" -d "${ROOTDIR}/build/debian/rootfs.e2:" -a

# package kernel individually
rm -f "${ROOTDIR}/images/linux/linux.tar*"
cd "${ROOTDIR}/images/linux"; tar -c --owner=root:0 -f "${ROOTDIR}/images/linux.tar" *; cd "${ROOTDIR}"

# Add overlay to rootfs
overlay_file() {
	while IFS='' read -r -a path; do
		mode=`stat --printf "%a\n" "${ROOTDIR}/overlay/${path}"`
		e2cp -v -G 0 -O 0 -P $mode -s "${ROOTDIR}/overlay" -d "${ROOTDIR}/build/debian/rootfs.e2:" -a $path
	done
}
overlay_link() {
	while IFS=' ' read -r -a args; do
		if [[ ${args[0]} = /* ]]; then
			# absolute links
			e2ln -v "${ROOTDIR}/build/debian/rootfs.e2:${args[0]}" "${args[1]}"
		else
			# relative links
			basedir="`dirname ${args[1]}`"
			e2ln -v "${ROOTDIR}/build/debian/rootfs.e2:${basedir}/${args[0]}" "${args[1]}"
		fi
	done
}
find "${ROOTDIR}/overlay" -type f -printf "%P\n" | overlay_file
find "${ROOTDIR}/overlay" -type l -printf "%l %P\n" | overlay_link

# assemble final disk image
rm -f "${ROOTDIR}/images/emmc.img"
dd if=/dev/zero of="${ROOTDIR}/images/emmc.img" bs=1 count=0 seek=$(($IMAGE_SIZE_MiB + 24))M
printf "o\nn\np\n1\n49152\n\na\nw\n" | fdisk "${ROOTDIR}/images/emmc.img"
dd of="${ROOTDIR}/images/emmc.img" if="${ROOTDIR}/build/debian/rootfs.e2" ibs=1M seek=24 obs=1M
echo "Finished generating disk image."
