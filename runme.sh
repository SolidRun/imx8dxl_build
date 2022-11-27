#!/bin/bash

### Options
: ${CROSS_COMPILE:=aarch64-linux-gnu-}
: ${SOC_REVISION:=A0}
: ${IMAGE_SIZE_MiB:=1000}

### Versions
ATF_GIT_URI=https://github.com/nxp-imx/imx-atf
ATF_RELEASE=tags/lf-5.15.52-2.1.0
UBOOT_GIT_URI=https://github.com/nxp-imx/uboot-imx
UBOOT_RELEASE=tags/lf-5.15.52-2.1.0
MKIMAGE_GIT_URI=https://github.com/nxp-imx/imx-mkimage
MKIMAGE_RELEASE=tags/lf-5.15.52-2.1.0
SECO_HTTP_URI=https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/imx-seco-5.8.7.1.bin
SECO_RELEASE=5.8.7.1
SCFW_FILE=L5.15.52_2.1.0_SCFWKIT-1.14.0.tar.gz
SCFW_FILE_URI="https://www.nxp.com/webapp/Download?colCode=L5.15.52_2.1.0_SCFWKIT-1.14.0&appType=license"
SCFW_RELEASE=1.14.0
LINUX_GIT_URI=https://github.com/nxp-imx/linux-imx
LINUX_RELEASE=lf-5.15.52-2.1.0

###

ROOTDIR=`pwd`

COMPONENTS="atf uboot mkimage seco scfw linux"
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
				mkdir "${ROOTDIR}/build/$i"
				cp -v "${ROOTDIR}/${!FILE_VAR}" "${ROOTDIR}/build/$i/"
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
				git am "$patch"

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
set -e
set -o pipefail

# Copy SECO FW
cd "${ROOTDIR}/build/seco"
cp -v imx-seco-${SECO_RELEASE}/firmware/seco/mx8dxl${SOC_REVISION,,}-ahab-container.img "${ROOTDIR}/build/mkimage/iMX8DXL/"
cp -v imx-seco-${SECO_RELEASE}/firmware/seco/mx8dxl${SOC_REVISION,,}-ahab-container.img "${ROOTDIR}/build/uboot/ahab-container.img"

# Build SCFW
cd "${ROOTDIR}/build/scfw/scfw_export_mx8"
make TOOLS="${ROOTDIR}/tools" R=${SOC_REVISION^^} B=evk D=0 M=0 dxl
cp -v build_mx8dxl_${SOC_REVISION,,}/scfw_tcm.bin "${ROOTDIR}/build/uboot/mx8dxl-evk-scfw-tcm.bin"
cp -v build_mx8dxl_${SOC_REVISION,,}/scfw_tcm.bin "${ROOTDIR}/build/mkimage/iMX8DXL/"

# Build ATF
cd "${ROOTDIR}/build/atf"
make -j$(nproc) CROSS_COMPILE="$CROSS_COMPILE" PLAT=imx8dxl bl31
cp -v build/imx8dxl/release/bl31.bin "${ROOTDIR}/build/mkimage/iMX8DXL/"

# Build u-boot
cd "${ROOTDIR}/build/uboot"
make CROSS_COMPILE="$CROSS_COMPILE" imx8dxl_v2x_defconfig
make -j$(nproc) CROSS_COMPILE="$CROSS_COMPILE"
cp -v u-boot.bin "${ROOTDIR}/build/mkimage/iMX8DXL/"

# Assemble bootable image
cd "${ROOTDIR}/build/mkimage"
make SOC=iMX8DXL REV=${SOC_REVISION^^} flash
mkdir -p ${ROOTDIR}/images
cp -v "${ROOTDIR}/build/mkimage/iMX8DXL/flash.bin" "${ROOTDIR}/images/uboot.bin"

echo "Finished compiling bootloader image."

# Build Linux
cd "${ROOTDIR}/build/linux"
find "${ROOTDIR}/configs/linux" -type f | sort | xargs ./scripts/kconfig/merge_config.sh -m arch/arm64/configs/imx_v8_defconfig /dev/null
make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
make -j$(nproc) ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" dtbs Image modules

rm -rf "${ROOTDIR}/images/linux"
mkdir -p "${ROOTDIR}/images/linux/boot/extlinux"
cp -v arch/arm64/boot/dts/freescale/imx8dxl*.dtb "${ROOTDIR}/images/linux/boot/"
cp -v arch/arm64/boot/Image "${ROOTDIR}/images/linux/boot/"
make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_PATH="${ROOTDIR}/images/linux/usr" modules_install
KRELEASE=`make kernelrelease`

cat > "${ROOTDIR}/images/linux/boot/extlinux/extlinux.conf" << EOF
label linux
	linux ../Image
	fdtdir ..
	append root=/dev/mmcblk0p1 ro rootwait
EOF

# Build V2X kernel drivers
if [[ -d ${ROOTDIR}/V2XSW ]]; then
	cd "${ROOTDIR}/V2XSW/src/saf-sdio"
	make -C "${ROOTDIR}/build/linux" CROSS_COMPILE="$CROSS_COMPILE" ARCH=arm64 M="$PWD" modules
	install -v -m644 -D saf_sdio.ko "${ROOTDIR}/images/linux/usr/lib/modules/${KRELEASE}/kernel/v2x/saf_sdio.ko"

	cd "${ROOTDIR}/V2XSW/src/cohda/kernel/drivers/cohda/llc"
	make -C "${ROOTDIR}/build/linux" CROSS_COMPILE="$CROSS_COMPILE" ARCH=arm64 M=$PWD BOARD=SRIMX8DXLSOM modules
	install -v -m644 -D cw-llc.ko "${ROOTDIR}/images/linux/usr/lib/modules/${KRELEASE}/kernel/v2x/cw-llc.ko"

	depmod -b "${ROOTDIR}/images/linux/usr" -F "${ROOTDIR}/build/linux/System.map" ${KRELEASE}
fi

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
		--include=apt-transport-https,bluez,busybox,ca-certificates,can-utils,command-not-found,curl,e2fsprogs,ethtool,fdisk,gpiod,gpsd,gpsd-tools,haveged,i2c-tools,ifupdown,iputils-ping,isc-dhcp-client,iw,initramfs-tools,locales,nano,net-tools,ntpdate,openssh-server,psmisc,python3-gps,python3-serial,rfkill,sudo,systemd-sysv,systemd-timesyncd,tio,usbutils,wget,wpasupplicant \
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

# populate fstab
printf "/dev/root / ext4 defaults 0 1\\n" > /etc/fstab

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
fi;

# Prepare final rootfs
cp rootfs.e2.orig rootfs.e2

# Add kernel to rootfs
find "${ROOTDIR}/images/linux" -type f -printf "%P\n" | e2cp -G 0 -O 0 -P 644 -s "${ROOTDIR}/images/linux" -d "${ROOTDIR}/build/debian/rootfs.e2:" -a

# Add overlay to rootfs
find "${ROOTDIR}/overlay" -type f -printf "%P\n" | e2cp -G 0 -O 0 -s "${ROOTDIR}/overlay" -d "${ROOTDIR}/build/debian/rootfs.e2:" -a

# assemble final disk image
rm -f "${ROOTDIR}/images/emmc.img"
dd if=/dev/zero of="${ROOTDIR}/images/emmc.img" bs=1 count=0 seek=$(($IMAGE_SIZE_MiB + 24))M
printf "o\nn\np\n1\n49152\n\na\nw\n" | fdisk "${ROOTDIR}/images/emmc.img"
dd of="${ROOTDIR}/images/emmc.img" if="${ROOTDIR}/build/debian/rootfs.e2" ibs=1M seek=24 obs=1M
echo "Finished generating disk image."
