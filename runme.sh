#!/bin/bash

### Options
: ${CROSS_COMPILE:=aarch64-linux-gnu-}
: ${SOC_REVISION:=A0}

### Versions
ATF_GIT_URI=https://source.codeaurora.org/external/imx/imx-atf
ATF_RELEASE=tags/lf-5.15.5-1.0.0
UBOOT_GIT_URI=https://source.codeaurora.org/external/imx/uboot-imx
UBOOT_RELEASE=tags/lf-5.15.5-1.0.0
MKIMAGE_GIT_URI=https://source.codeaurora.org/external/imx/imx-mkimage
MKIMAGE_RELEASE=tags/lf-5.15.5-1.0.0
SECO_HTTP_URI=https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/imx-seco-3.8.5.bin
SECO_RELEASE=3.8.5
SCFW_FILE=imx-scfw-porting-kit-1.12.1.tar.gz
SCFW_FILE_URI="https://www.nxp.com/webapp/Download?colCode=L5.15.5_1.0.1_SCFWKIT-1.12.1&appType=license"
SCFW_RELEASE=1.12.1
LINUX_GIT_URI=https://source.codeaurora.org/external/imx/linux-imx
LINUX_RELEASE=lf-5.15.5-1.0.0
DEBIAN_HTTP_URI=https://cloud.debian.org/images/cloud/bullseye/20220711-1073/debian-11-nocloud-arm64-20220711-1073.tar.xz

###

ROOTDIR=`pwd`

COMPONENTS="atf uboot mkimage seco scfw linux debian"
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
			TARBALL=imx-scfw-porting-kit-${SCFW_RELEASE}.tar*
			tar --wildcards --strip-components=2 -xvf $TARBALL "*.bin"

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
make CROSS_COMPILE="$CROSS_COMPILE" imx8dxl_evk_defconfig
make -j$(nproc) CROSS_COMPILE="$CROSS_COMPILE"
cp -v u-boot.bin "${ROOTDIR}/build/mkimage/iMX8DXL/"

# Assemble bootable image
cd "${ROOTDIR}/build/mkimage"
make SOC=iMX8DXL REV=${SOC_REVISION^^} flash
cp -v "${ROOTDIR}/build/mkimage/iMX8DXL/flash.bin" "${ROOTDIR}/images/uboot.bin"

echo "Finished compiling bootloader image."

# Build Linux
cd "${ROOTDIR}/build/linux"
find "${ROOTDIR}/configs/linux" -type f | sort | xargs ./scripts/kconfig/merge_config.sh -m arch/arm64/configs/imx_v8_defconfig /dev/null
make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig
make -j$(nproc) ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" dtbs Image modules

rm -rf "${ROOTDIR}/images/linux"
mkdir -p "${ROOTDIR}/images/linux/boot"
cp -v arch/arm64/boot/dts/freescale/imx8dxl*.dtb "${ROOTDIR}/images/linux/boot/"
cp -v arch/arm64/boot/Image "${ROOTDIR}/images/linux/boot/"
make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_PATH="${ROOTDIR}/images/linux/usr" modules_install
KRELEASE=`make kernelrelease`

cat > "${ROOTDIR}/images/linux/boot/extlinux.conf" << EOF
label linux
	linux Image
	fdtdir .
	append root=/dev/mmcblk0p1 ro rootwait
EOF

# Build V2X kernel drivers
if [[ -d ${ROOTDIR}/V2XSW ]]; then
	cd "${ROOTDIR}/V2XSW/src/saf-sdio"
	make -C "${ROOTDIR}/build/linux" CROSS_COMPILE="$CROSS_COMPILE" ARCH=arm64 M="$PWD" modules
	install -v -m644 -D saf_sdio.ko "${ROOTDIR}/images/linux/usr/lib/modules/${KRELEASE}/kernel/v2x/saf_sdio.ko"

	cd "${ROOTDIR}/V2XSW/src/cohda/kernel/drivers/cohda/llc"
	make -C "${ROOTDIR}/build/linux" CROSS_COMPILE="$CROSS_COMPILE" ARCH=arm64 M=$PWD modules
	install -v -m644 -D cw-llc.ko "${ROOTDIR}/images/linux/usr/lib/modules/${KRELEASE}/kernel/v2x/cw-llc.ko"

	depmod -b "${ROOTDIR}/images/linux/usr" -F "${ROOTDIR}/build/linux/System.map" ${KRELEASE}
fi

# Integrate with rootfs
cd "${ROOTDIR}/build/debian"
tar -xf debian*.tar.xz
test -f disk.raw
# extract (root) partition at block 262144
dd if=disk.raw of=rootfs.e2 ibs=1024 skip=131072 obs=4096
# copy kernel into rootfs
find "${ROOTDIR}/images/linux" -type f -printf "%P\n" | e2cp -G 0 -O 0 -P 644 -s "${ROOTDIR}/images/linux" -d "${ROOTDIR}/build/debian/rootfs.e2:" -a

# Add files from overlay, if any
find "${ROOTDIR}/overlay" -type f -printf "%P\n" | e2cp -G 0 -O 0 -s "${ROOTDIR}/overlay" -d "${ROOTDIR}/build/debian/rootfs.e2:" -a

# assemble final disk image
dd of="${ROOTDIR}/images/emmc.img" if=disk.raw bs=1024 count=131072
dd of="${ROOTDIR}/images/emmc.img" if=rootfs.e2 ibs=4096 seek=131072 obs=1024
# U-Boot conflicts with Debian choice of offset for EFI partition :(
#dd of="${ROOTDIR}/images/emmc.img" if="${ROOTDIR}/images/uboot.bin" bs=1024 seek=32 conv=notrunc
