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

###

ROOTDIR=`pwd`

COMPONENTS="atf uboot mkimage seco scfw"
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

echo "Finished compiling bootloader image."
exit 0
