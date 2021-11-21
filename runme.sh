#!/bin/bash
set -e

BASE_DIR=`pwd`

export PATH=$BASE_DIR/build/toolchain/gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu/bin:$PATH
export TOOLS=$BASE_DIR/build/toolchain2/
export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64

mkdir -p $BASE_DIR/build


###################################################################################################################################
#							DOWNLOAD Toolchain

if [[ ! -d $BASE_DIR/build/toolchain ]]; then
	mkdir $BASE_DIR/build/toolchain
	cd $BASE_DIR/build/toolchain
	wget https://releases.linaro.org/components/toolchain/binaries/7.4-2019.02/aarch64-linux-gnu/gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu.tar.xz
	tar -xvf gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu.tar.xz
fi

###################################################################################################################################




###################################################################################################################################
#							DOWNLOAD SCFW Toolchain

if [[ ! -d $BASE_DIR/build/toolchain2 ]]; then
	mkdir $BASE_DIR/build/toolchain2
	cd $BASE_DIR/build/toolchain2
	wget https://developer.arm.com/-/media/Files/downloads/gnu-rm/8-2018q4/gcc-arm-none-eabi-8-2018-q4-major-linux.tar.bz2
	tar -xvf gcc-arm-none-eabi-8-2018-q4-major-linux.tar.bz2
fi

###################################################################################################################################



###################################################################################################################################
#							DOWNLOAD SECO FW

if [[ ! -d $BASE_DIR/build/firmware ]]; then
	mkdir $BASE_DIR/build/firmware
	cd $BASE_DIR/build/firmware
	wget https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/imx-seco-3.7.1.bin
fi

###################################################################################################################################




###################################################################################################################################
#							CLONE mkimage
MKIMAGE_TAG=rel_imx_5.4.47_2.2.0

if [[ ! -d $BASE_DIR/build/imx-mkimage ]]; then
	cd $BASE_DIR/build
	git clone https://source.codeaurora.org/external/imx/imx-mkimage -b $MKIMAGE_TAG --depth 1
fi

###################################################################################################################################





###################################################################################################################################
#							CLONE U-boot
U_BOOT_TAG=imx_v2020.04_5.4.70_2.3.0

if [[ ! -d $BASE_DIR/build/uboot-imx ]]; then
	cd $BASE_DIR/build
	git clone https://source.codeaurora.org/external/imx/uboot-imx -b $U_BOOT_TAG --depth 1
	cd uboot-imx
	git am $BASE_DIR/patches/uboot/*.patch
fi

###################################################################################################################################




###################################################################################################################################
#							CLONE Linux Kernel
KERNEL_TAG=rel_imx_5.4.47_2.2.0

if [[ ! -d $BASE_DIR/build/linux-imx ]]; then
	cd $BASE_DIR/build
        git clone https://source.codeaurora.org/external/imx/linux-imx -b $KERNEL_TAG --depth 1
fi

###################################################################################################################################




###################################################################################################################################
#							CLONE Buildroot
BUILDROOT_VERSION=2020.02

if [[ ! -d $BASE_DIR/build/buildroot ]]; then
	cd $BASE_DIR/build
	git clone https://github.com/buildroot/buildroot -b $BUILDROOT_VERSION --depth=1
fi

###################################################################################################################################




###################################################################################################################################
#                                                       CLONE ATF
ATF_TAG=rel_imx_5.4.70_2.3.0

if [[ ! -d $BASE_DIR/build/imx-atf ]]; then
        cd $BASE_DIR/build
        git clone https://source.codeaurora.org/external/imx/imx-atf -b $ATF_TAG --depth 1
fi

###################################################################################################################################


mkdir -p $BASE_DIR/tmp





##################################################################################################################################
#                                                      BUILD SECO Firmware

cd $BASE_DIR/build/firmware
chmod a+x imx-seco-3.7.1.bin

if [[ ! -d $BASE_DIR/build/firmware/imx-seco-3.7.1 ]]; then
	bash imx-seco-3.7.1.bin --auto-accept
fi
cp imx-seco-3.7.1/firmware/seco/mx8dxla0-ahab-container.img $BASE_DIR/tmp


###################################################################################################################################




###################################################################################################################################
#                                                      BUILD SCFW 


if [[ ! -d $BASE_DIR/build/scfw ]]; then
	mkdir $BASE_DIR/build/scfw 
	cp $BASE_DIR/scfw/imx-scfw-porting-kit-1.6.0.tar.gz $BASE_DIR/build/scfw
	cd $BASE_DIR/build/scfw
	tar -xvf imx-scfw-porting-kit-1.6.0.tar.gz
	cd packages
	chmod a+x imx-scfw-porting-kit-1.6.0.bin
	bash imx-scfw-porting-kit-1.6.0.bin --auto-accept
	cd imx-scfw-porting-kit-1.6.0/src
	tar zxvf scfw_export_mx8dxl_a0.tar.gz
	cd scfw_export_mx8dxl_a0
	make -j32 dxl R=a0
	cp build_mx8dxl_a0/scfw_tcm.bin $BASE_DIR/tmp
fi

###################################################################################################################################




###################################################################################################################################
#                                                       BUILD ATF
PLAT=imx8dxl

cd $BASE_DIR/build/imx-atf
make -j32 PLAT=$PLAT bl31
cp build/$PLAT/release/bl31.bin ${BASE_DIR}/tmp/


###################################################################################################################################




###################################################################################################################################
#                                                       BUILD U-BOOT
U_BOOT_DEFCONFIG=imx8dxl_evk_defconfig

cd $BASE_DIR/build/uboot-imx
make -j32 $U_BOOT_DEFCONFIG
make -j32 
cp u-boot.bin ${BASE_DIR}/tmp/


###################################################################################################################################





###################################################################################################################################
#                                                       GENERATE flash.bin

cd $BASE_DIR/build/imx-mkimage/
cp $BASE_DIR/tmp/scfw_tcm.bin iMX8DXL/
cp $BASE_DIR/tmp/mx8dxla0-ahab-container.img iMX8DXL/
cp $BASE_DIR/tmp/bl31.bin iMX8DXL/
cp $BASE_DIR/tmp/u-boot.bin iMX8DXL/
make -j32 SOC=iMX8DXL REV=a0 flash

cp iMX8DXL/flash.bin $BASE_DIR/tmp/

###################################################################################################################################





###################################################################################################################################
#                                                       BUILD Linux
LINUX_DEFCONFIG=imx_v8_defconfig

cd $BASE_DIR/build/linux-imx
make -j32 $LINUX_DEFCONFIG
make -j32 Image dtbs


cp arch/arm64/boot/Image $BASE_DIR/tmp/Image
cp arch/arm64/boot/dts/freescale/imx8dxl-evk.dtb $BASE_DIR/tmp/imx8dxl-evk.dtb

###################################################################################################################################




###################################################################################################################################
#                                                       BUILD Buildroot
BUILDROOT_DEFCONFIG=imx8dxl_defconfig

cd $BASE_DIR/build/buildroot
cp $BASE_DIR/configs/buildroot configs/$BUILDROOT_DEFCONFIG
make -j32 $BUILDROOT_DEFCONFIG
make -j32

cp output/images/rootfs.cpio.uboot $BASE_DIR/tmp/rootfs.cpio
cp output/images/rootfs.ext2 $BASE_DIR/tmp/rootfs.ext2

###################################################################################################################################


mkdir -p $BASE_DIR/output




###################################################################################################################################
#                                                       MAKE Image


#Image name should include the commit hash
cd $BASE_DIR
COMMIT_HASH=`git log -1 --pretty=format:%h`
IMAGE_NAME=microsd-${COMMIT_HASH}.img


dd if=/dev/zero of=$BASE_DIR/tmp/part1.fat32 bs=1M count=148
env PATH="$PATH:/sbin:/usr/sbin" mkdosfs $BASE_DIR/tmp/part1.fat32

echo "label linux" > $BASE_DIR/tmp/extlinux.conf
echo "        linux ../Image" >> $BASE_DIR/tmp/extlinux.conf
echo "        fdt ../imx8dxl-evk.dtb" >> $BASE_DIR/tmp/extlinux.conf
echo "        initrd ../rootfs.cpio.uboot" >> $BASE_DIR/tmp/extlinux.conf


mmd -i $BASE_DIR/tmp/part1.fat32 ::/extlinux
mmd -i $BASE_DIR/tmp/part1.fat32 ::/boot


mcopy -i $BASE_DIR/tmp/part1.fat32 $BASE_DIR/tmp/extlinux.conf ::/extlinux/extlinux.conf
mcopy -i $BASE_DIR/tmp/part1.fat32 $BASE_DIR/tmp/Image ::/boot/Image
mcopy -s -i $BASE_DIR/tmp/part1.fat32 $BASE_DIR/tmp/imx8dxl-evk.dtb ::/boot/imx8dxl-evk.dtb
mcopy -s -i $BASE_DIR/tmp/part1.fat32 $BASE_DIR/tmp/rootfs.cpio ::/boot/rootfs.cpio


dd if=/dev/zero of=$BASE_DIR/output/$IMAGE_NAME bs=1M count=301
dd if=$BASE_DIR/tmp/flash.bin of=$BASE_DIR/output/$IMAGE_NAME bs=1K seek=32 conv=notrunc

env PATH="$PATH:/sbin:/usr/sbin" parted --script $BASE_DIR/output/${IMAGE_NAME} mklabel msdos mkpart primary 2MiB 150MiB mkpart primary 150MiB 300MiB

dd if=$BASE_DIR/tmp/part1.fat32 of=$BASE_DIR/output/$IMAGE_NAME bs=1M seek=2 conv=notrunc
dd if=$BASE_DIR/tmp/rootfs.ext2 of=$BASE_DIR/output/$IMAGE_NAME bs=1M seek=150 conv=notrunc

printf "\n\nImage file: $BASE_DIR/output/$IMAGE_NAME\n\n"

###################################################################################################################################

