# SolidRun's i.MX8DXL V2X SoM build scripts

## Introduction
Main intention of this repository is to produce a Debian based build environment for i.MX8DXL product evaluation.

The build script provides ready to use images that can be deployed on eMMC or booted via USB-OTG.

## Build with Docker
A docker image providing a consistent build environment can be used as below:

1. build container image (first time only)
   ```
   docker build -t imx8dxl_build docker
   # optional with an apt proxy, e.g. apt-cacher-ng
   # docker build --build-arg APTPROXY=http://127.0.0.1:3142 -t imx8mm_build docker
   ```
2. invoke build script in working directory
   ```
   docker run -i -t -v "$PWD":/work imx8dxl_build -u $(id -u) -g $(id -g)
   ```

### rootless Podman

Due to the way podman performs user-id mapping, the root user inside the container (uid=0, gid=0) will be mapped to the user running podman (e.g. 1000:100).
Therefore in order for the build directory to be owned by current user, `-u 0 -g 0` have to be passed to *docker run*.

## Build with host tools
Simply running ./runme.sh, it will check for required tools, clone and build images and place results in images/ directory.

## Configure Boot Mode DIP Switch

This table indicates valid boot-modes selectable via the DIP switch S1 on the Molex Carrier.
The value 0 indicates OFF, and 1 indicates the ON state.

| Switch             | 1 | 2 |
|--------------------|---|---|
| selected by eFuses | 0 | 0 |
| eMMC               | 0 | 1 |
| USB-OTG            | 1 | 0 |

## Boot via USB-OTG

All steps in this section require using NXPs `uuu` application to interface with the Boot-ROM inside the SoC. Precompiled binaries are available [here on GitHub](https://github.com/NXPmicro/mfgtools/releases), and through the package managers on some distributions.

### U-Boot only

0. Configure the DIP Switch to boot from USB. This step is optional *only before flashing a bootloader to eMMC*
1. Connect the serial console to the computer, and open it.
2. Connect the first USB-OTG port via a type A to type A cable to the computer.
3. Acquire the full path to the uuu command (e.g. `C:\Users\Josua\Desktop\uuu.exe`) or copy it into the imx8dxl_build folder.
4. From a CLI at the root of imx8dxl_build folder, Instruct NXPs `uuu` command to send U-Boot:
   `[path-to-]uuu images/uboot.bin`
5. Connect to power, or reset the device.
6. The serial console should now provide access to the early boot log, and u-boot commandline:

       U-Boot 2021.04-00001-g6f4a2fe897 (Jul 24 2022 - 11:18:25 +0000)

       CPU:   NXP i.MX8DXL RevA1 A35 at 1200 MHz at 37C

       Model: NXP i.MX8DXL EVK Board
       Board: iMX8DXL EVK
       Boot:  USB
       DRAM:  1019.8 MiB
       MMC:   FSL_SDHC: 0, FSL_SDHC: 1
       Loading Environment from MMC... MMC: no card present
       *** Warning - No block device, using default environment

       In:    serial
       Out:   serial
       Err:   serial

        BuildInfo:
         - SCFW c1e35e09, SECO-FW b3c3cbc7, IMX-MKIMAGE 22346a32, ATF 05f788b
         - U-Boot 2021.04-00001-g6f4a2fe897
         - V2X-FW 2c8f793d version 0.0.4

       MMC: no card present
       Detect USB boot. Will enter fastboot mode!
       Net:   pca953x gpio@20: Error reading direction register

       Warning: ethernet@5b050000 (eth1) using random MAC address - ca:ef:1c:f5:5c:db
       eth1: ethernet@5b050000 [PRIME]
       Fastboot: Normal
       Boot from USB for mfgtools
       *** Warning - Use default environment for                                mfgtools
       , using default environment

       Run bootcmd_mfg: run mfgtool_args;if iminfo ${initrd_addr}; then if test ${tee} = yes; then bootm ${tee_addr} ${initrd_addr} ${fdt_addr}; else booti ${loadaddr} ${initrd_addr} ${fdt_addr}; fi; else echo "Run fastboot ..."; fastboot auto; fi;
       Hit any key to stop autoboot:  0

       ## Checking Image at 83100000 ...
       Unknown image format!
       Run fastboot ...
       auto usb 0

   The last line indicates that the bootloader is waiting for further USB commands via the fastboot protocol. By pressing Ctrl+C the U-Boot commandline can be accessed instead.

## Flash Disk Image to eMMC

All steps in this section require using NXPs `uuu` application to interface with the Boot-ROM inside the SoC. Precompiled binaries are available [here on GitHub](https://github.com/NXPmicro/mfgtools/releases), and through the package managers on some distributions.

0. Configure the DIP Switch to boot from USB. This step is optional *only before flashing the eMMC for the first time*
1. Connect the serial console to the computer, and open it.
2. Connect the first USB-OTG port via a type A to type A cable to the computer.
3. Acquire the full path to the uuu command (e.g. `C:\Users\Josua\Desktop\uuu.exe`) or copy it into the imx8dxl_build folder.
4. From a CLI at the root of imx8dxl_build folder, Instruct NXPs `uuu` command to execute the flash-emmc.uuu script, to write `images/emmc.img` and `images/uboot.bin` to the eMMC:
   `[path-to-]uuu flash-emmc.uuu`
5. Connect to power, or reset the device.
6. The serial console should now provide access to the early boot log, and indicate writing to the eMMC:

       Run fastboot ...
       auto usb 0
       Detect USB boot. Will enter fastboot mode!
       flash target is MMC:1
       MMC: no card present
       MMC card init failed!
       MMC: no card present
       ** Block device MMC 1 not supported
       Detect USB boot. Will enter fastboot mode!
       flash target is MMC:0
       switch to partitions #0, OK
       mmc0(part 0) is current device
       Detect USB boot. Will enter fastboot mode!
       Starting download of 16776232 bytes
       ..........................................................................
       .....................................................
       downloading of 16776232 bytes finished
       writing to partition 'all'
       sparse flash target is mmc:0
       writing to partition 'all' for sparse, buffer size 16776232
       Flashing sparse image at offset 0
       Flashing Sparse Image
       ........ wrote 16776192 bytes to 'all'

       ...

7. Once the `uuu` command indicates "done", the flashing is complete.

## Get Started

After flashing the eMMC and booting into Linux, the serial console must be used for logging into the root account for the first time.
Simply enter "root" and press return:

    Debian GNU/Linux 11 e7c450f97e59 ttyLP0

    e7c450f97e59 login: root
    Linux e7c450f97e59 5.15.5-00002-g0c527c0172f1-dirty #19 SMP PREEMPT Sun Aug 7 13:39:57 UTC 2022 aarch64

    The programs included with the Debian GNU/Linux system are free software;
    the exact distribution terms for each program are described in the
    individual files in /usr/share/doc/*/copyright.

    Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
    permitted by applicable law.

    root@e7c450f97e59:~#

### USB Networking

The system is preconfigured as a USB Ethernet Gadget. Via the same USB connection used for booting and flashing the eMMC, your computer should be detecting a generic usb network interface once Linux has booted. This allows e.g. for internet connection sharing, or simple peer to peer networking.
By default the system tries to acquire an IP address and DNS configuration via DHCP.

### Log-In via SSH

To log in via SSH, an ssh key must be installed first. Copy your favourite public key, e.g. from `~/.ssh/id_ed25519.pub`, into a new file in the root users home directory at `~/.ssh/authorized_keys`:

root@e7c450f97e59:~# mkdir .ssh
root@e7c450f97e59:~# cat > .ssh/authorized_keys << EOF
ssh-ed25519 AAAAinsertyour pubkey@here
EOF

### Expand Root Filesystem

After flashing the root filesystem is smaller than the eMMC. To utilize all space, resize both the rootfs partition - and then the filesystem:

1. inspect partitions:

   Using fdisk, view the current partitions. Take note of the start sector for partition 1!

       root@e7c450f97e59:~# fdisk /dev/mmcblk0

       Welcome to fdisk (util-linux 2.36.1).
       Changes will remain in memory only, until you decide to write them.
       Be careful before using the write command.


       Command (m for help): p
       Disk /dev/mmcblk0: 7.28 GiB, 7820083200 bytes, 15273600 sectors
       Units: sectors of 1 * 512 = 512 bytes
       Sector size (logical/physical): 512 bytes / 512 bytes
       I/O size (minimum/optimal): 512 bytes / 512 bytes
       Disklabel type: dos
       Disk identifier: 0xcc3ec3d4

       Device         Boot Start      End  Sectors  Size Id Type
       /dev/mmcblk0p1      49152  2690687  2641535  1.3G 83 Linux

       Command (m for help):

2. resize partition 1:

   Drop and re-create partition 1 at the same starting sector noted before, keeping the ext4 signature when prompted:

       Command (m for help): d
       Selected partition 1
       Partition 1 has been deleted.

       Command (m for help): n
       Partition type
          p   primary (0 primary, 0 extended, 4 free)
          e   extended (container for logical partitions)
       Select (default p): p
       Partition number (1-4, default 1): 1
       First sector (2048-15273599, default 2048): 49152
       Last sector, +/-sectors or +/-size{K,M,G,T,P} (49152-15273599, default 15273599):

       Created a new partition 1 of type 'Linux' and of size 7.3 GiB.
       Partition #1 contains a ext4 signature.

       Do you want to remove the signature? [Y]es/[N]o: N

       Command (m for help): p

       Disk /dev/mmcblk0: 7.28 GiB, 7820083200 bytes, 15273600 sectors
       Units: sectors of 1 * 512 = 512 bytes
       Sector size (logical/physical): 512 bytes / 512 bytes
       I/O size (minimum/optimal): 512 bytes / 512 bytes
       Disklabel type: dos
       Disk identifier: 0xcc3ec3d4

       Device         Boot Start      End  Sectors  Size Id Type
       /dev/mmcblk0p1      49152 15273599 15224448  7.3G 83 Linux

       Command (m for help): w
       The partition table has been altered.
       Syncing disks.

3. resize root filesystem:

   Linux supports online-resizing for the ext4 filesystem. Invoke `resize2fs` on partition 1 to do so:

       root@e7c450f97e59:~# resize2fs /dev/mmcblk0p1

## Initialise Roadlink SAF5400 Modem

Note that this step requires access to the partially proprietary software-stack by NXP.
Customers can request access to a standalone zip file with all required pieces, based on NXPs v0.13 release, along with patches for initial support of our SoM.

### Compile Kernel Modules

To compile the kernel drivers as part of executing `runme.sh`, the zip file must be unpacked inside `imx8dxl_build` to create the `V2XSW` folder.
The build script will pick up sources from there and compile both `saf_sdio.ko` and `cw-llc.ko` automatically, and include them in the disk image.

Install them by flashing the new disk image, or copying individually (`images/linux/usr/lib/modules/*/kernel/v2x/{saf_sdio.ko,cw-llc.ko}`).

### Compile Application(s)

The utilities for booting firmware on the Modem can be installed natively from the running system.
Copy the zipfile to the system, e.g. via `scp` - then follow below commands:

    apt-get install build-essential libpcap-dev libgps-dev unzip net-tools

    unzip V2XSW.zip
    cd V2XSW

    # APPLY PATCHES

    pushd src/cohda/app/llc
    make BOARD=aarch64 -j2
    make install
    popd

    pushd src/eab
    make -j2
    make install
    popd

    sudo install -c src/saf-sdio/include/saf_sdio.h /usr/include/linux/

    pushd src/saf-bridge
    make
    make install
    popd

    pushd src/v2x_saf_boot/v2xHostBootApp
    make V2X_TARGET=srimx8dxlsom
    make V2X_TARGET=srimx8dxlsom install
    popd

    pushd src/saf-boot
    make V2X_TARGET=evkLinux -j2
    make V2X_TARGET=evkLinux install
    popd

    pushd src/saf-initscripts
    sudo make install
    popd

### Boot the Modem

SAF5400 requires particular initialisation steps in precise order to properly start.
Integration with the `saf_start` init-script is desirable - currently however the following commands need to be exected manually or in a script:

    #!/bin/bash

    rmmod cw-llc 2>/dev/null || true
    rmmod saf_sdio 2>/dev/null || true

    if [ ! -e /sys/class/gpio/gpio41 ]; then
      echo 41 > /sys/class/gpio/export
      echo out > /sys/class/gpio/gpio41/direction
    fi
    if [ ! -e /sys/class/gpio/gpio42 ]; then
      echo 42 > /sys/class/gpio/export
      echo out > /sys/class/gpio/gpio42/direction
    fi

    # set boot-mode to sdio
    echo 1 > /sys/class/gpio/gpio41/value

    # reset
    echo 1 > /sys/class/gpio/gpio42/value
    echo 5b020000.mmc > /sys/bus/platform/drivers/sdhci-esdhc-imx/unbind
    echo 0 > /sys/class/gpio/gpio42/value
    sleep 1
    echo 1 > /sys/class/gpio/gpio42/value
    echo in > /sys/class/gpio/gpio41/direction
    echo 5b020000.mmc > /sys/bus/platform/drivers/sdhci-esdhc-imx/bind
    sleep 1
    rmmod cw-llc

    # load firmware
    modprobe saf_sdio
    sleep 1
    v2x_saf_boot -W 1 -D SDIO -l /lib/firmware/SAF5X00_SBL.bin
    v2x_saf_boot -W 1 -D SDIO -L /lib/firmware/SAF5X00_SDR_SDIO.bin
    rmmod saf_sdio

    # start llc driver
    rmmod saf_sdio
    modprobe cw-llc TransferMode=2
    echo "1" > /proc/sys/net/ipv6/conf/cw-llc0/disable_ipv6
    ip link set cw-llc0 up

    # show version
    llc version

### Flash Firmware to dedicated SPI

The SAF5400 is directly connected to an SPI flash which can be used as boot media to load firmware after reset, if the boot-mode gpio is level 0.
Once flashed, the start commands from the previous section can be tuned boot from spi after reset.

Firmware can be flashed *after booting SBL from sdio **but before booting SDR*** with the v2x_saf_boot application.
Stop the initialisation sequence from the previous section *before `v2x_saf_boot ... SAF5X00_SDR_SDIO.bin`, then:

    # erase flash (optional)
    v2x_saf_boot -W 1 -D SDIO -E 10
    # write application
    v2x_saf_boot -W 1 -D SDIO -F /usr/lib/firmware/SAF5X00_SDR_SDIO_FLASH.bin 0x00 -I 0x00

#### Boot the Modem from SPI

The initialisation sequence for booting the Modem from SPI flash is similar to booting from MDIO with only minor changes:

- Boot-Mode pin should be pulled low during reset
- bind must be delayed so that saf_sdio doesn't prevent spi boot
- skip loading firmware with v2x_saf_boot

The following script implements a reset and this adapted initialisation sequence:

    #!/bin/bash

    rmmod cw-llc 2>/dev/null || true
    rmmod saf_sdio 2>/dev/null || true

    if [ ! -e /sys/class/gpio/gpio41 ]; then
      echo 41 > /sys/class/gpio/export
      echo out > /sys/class/gpio/gpio41/direction
    fi
    if [ ! -e /sys/class/gpio/gpio42 ]; then
      echo 42 > /sys/class/gpio/export
      echo out > /sys/class/gpio/gpio42/direction
    fi

    # set boot-mode to spi
    echo 0 > /sys/class/gpio/gpio41/value

    # reset
    echo 1 > /sys/class/gpio/gpio42/value
    echo 5b020000.mmc > /sys/bus/platform/drivers/sdhci-esdhc-imx/unbind
    echo 0 > /sys/class/gpio/gpio42/value
    sleep 1
    echo 1 > /sys/class/gpio/gpio42/value
    echo in > /sys/class/gpio/gpio41/direction
    sleep 1
    echo 5b020000.mmc > /sys/bus/platform/drivers/sdhci-esdhc-imx/bind
    sleep 1
    rmmod cw-llc
    rmmod saf_sdio

    # start llc driver
    modprobe cw-llc TransferMode=2
    echo "1" > /proc/sys/net/ipv6/conf/cw-llc0/disable_ipv6
    ip link set cw-llc0 up

    # show version
    llc version

### Calibration

By default on power-up the SAF5400 tries to load calibration from the connected EEPROM, and falls back to defaults otherwise.
The current calibration can be retrieved from the modem as structured text file, and re-applied after making appropriate changes:

    # read active calibration
    llc calib -g > calib.txt
    # edit calib.txt
    # apply changed calibration
    llc calib -s < calib.txt

## IOs (Adapter Board)

### CAN-Bus (J8, J9)

After booting the CAN network interfaces will show up in the output of the `ip` utility:

    root@f9c5d243692b:~# ip addr
    ...
    4: can0: <NOARP,ECHO> mtu 16 qdisc noop state DOWN group default qlen 10
        link/can
    5: can1: <NOARP,ECHO> mtu 16 qdisc noop state DOWN group default qlen 10
        link/can

For transmitting packets it is required to configure a bitrate and set link state up.
Then data can be exchanged e.g. with the `candump` and `cansend` commands from `can-utils` package:

    apt-get install can-utils
    ip link set can0 up type can bitrate 125000 restart-ms 100
    ip link set dev can0 up
    ip -details -statistics link show can0
    ip link set can1 up type can bitrate 125000
    ip link set dev can1 up
    ip -details -statistics link show can1

    # To receive data
    candump can0

    # To send data
    cansend can1 "123#c0ffee"

Note: the CAN interfaces are not functional on early samples manufactured before October!

### Digital Inputs (J4)

Userspace access to the two digital inputs on J4 pins 1+2 is available through the gpiod library.
As examples and for simple usecases it provides utilities to lookup, control and monitor the varioaus GPIos on a system.

Reading from the two inputs can be achieved through the following commands:

    # 1. find the gpiochip instance and numbers:
    root@f9c5d243692b:~# gpiofind DIG_IN1
    gpiochip8 0
    root@f9c5d243692b:~# gpiofind DIG_IN2
    gpiochip8 1
    # --> the inputs are on chip number 8, lines 0+1

    # 2. read values from chip 8 lines 0+1
    root@f9c5d243692b:~# gpioget 8 0 1
    1 1

A Reading of 1 means that both pins are floating, not connected to a voltage supply.
Applying 5V or more will toggle the respective reading to 0.

### Digital Outpouts (J6)

Pins 0+1 on J6 provide switchable 12V from the board power supply through relays.

Their state can be toggled from GPIOs, e.g. through libgpiod, or the libgpiod utilities:

    # 1. find the gpiochip instance and numbers:
    root@f9c5d243692b:~# gpiofind DIG_OUT1
    gpiochip8 4
    root@f9c5d243692b:~# gpiofind DIG_OUT2
    gpiochip8 5
    # --> the outputs are on chip number 8, lines 4+5

    # 2. enable both relays for 10 seconds
    gpioset -m time -s 10 8 4=1 5=1

    # 3. disable both relays for 10 seconds
    gpioset -m time -s 10 8 4=0 5=0

## Ethernet Switch

The carrier features an SJA1110A ethernet switch supporting a wide mix of ports such as T1, 100base-tx, 1000base-tx and 2500base-tx.
Externally exposed on the Adapter Board are 1x 100Base-TX and 1x T1, backed by a 1000Mbps RGMII link from the switch to the CPU.

Linux uses the DSA Framework for management of switch ports: Any port on the switch will appear as a normal network interface and can be controlled by the standard Linux utilities such as `ethtool, ip, ifconfig, etc.`.
Note that by design of DSA the cpu port - `eth0` should **not be used directly**. Instead - when the behaviour of a dumb switch is desired, a linux bridge interface should be created covering all ports.

### 100Base-TX

Switch port #1 is exposed on the V2X Adapter as "lan1":

    # ifconfig -a
    lan1: flags=4098<BROADCAST,MULTICAST>  mtu 1500
            ether 96:d1:b9:ea:48:07  txqueuelen 1000  (Ethernet)
            RX packets 1111  bytes 136285 (133.0 KiB)
            RX errors 0  dropped 0  overruns 0  frame 0
            TX packets 12  bytes 936 (936.0 B)
            TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

Due to a bug in the switch driver, the phy will not turn on by itself.
As a workaround - install [phytool](https://github.com/wkz/phytool.git) - then unset bit 0 at register 0x18 - to disable power-down mode:

    phy=lan1/1; phytool write $phy/0x18 0x60

#### MDIX

Auto-MDIX is not supported for 100Base-TX.
For direct device to device connections a crossover cable is recommended.

Alternatively manual MDIX is supported through PHY register 0x11 bit 6:

    phy=lan1/1; phytool write $phy/0x11 0x40

### T1

Switch port #10 is exposed on the V2X Adapter as "trx6":

    # ifconfig -a
    trx6: flags=4098<BROADCAST,MULTICAST>  mtu 1500
            inet 192.168.20.1  netmask 255.255.255.0  broadcast 0.0.0.0
            ether 96:d1:b9:ea:48:07  txqueuelen 1000  (Ethernet)
            RX packets 0  bytes 0 (0.0 B)
            RX errors 0  dropped 0  overruns 0  frame 0
            TX packets 32  bytes 2308 (2.2 KiB)
            TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

Note that the PHY does not support automatic negotiation for slave and master roles.
To achieve link up between two devices, both sides must be explicitly configured:

    ethtool -s trx6 master-slave forced-slave
    ethtool -s trx6 master-slave forced-master
