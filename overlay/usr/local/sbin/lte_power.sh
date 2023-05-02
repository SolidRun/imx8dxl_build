#!/bin/bash

GPIO_RESETN=43 # 1*32+11
GPIO_PWRKEY=44 # 1*32+12

for gpio in $GPIO_RESETN $GPIO_PWRKEY; do
    if [ ! -e /sys/class/gpio/gpio$gpio ]; then
        echo $gpio > /sys/class/gpio/export
    fi
    echo out > /sys/class/gpio/gpio$gpio/direction
done

cat /sys/class/gpio/gpio$GPIO_RESETN/value
cat /sys/class/gpio/gpio$GPIO_PWRKEY/value

# Initial Settings:
# - disable vbat
# - assert reset
# - deassert power key
echo disabled > /sys/devices/platform/userspace-consumer-lte-vbat/state
echo 0 > /sys/class/gpio/gpio$GPIO_RESETN/value
echo 0 > /sys/class/gpio/gpio$GPIO_PWRKEY/value

sleep 1

# Power-On Sequence:
# - enable vbat
# - deassert reset
# - toggle power key
echo enabled > /sys/devices/platform/userspace-consumer-lte-vbat/state
echo 1 > /sys/class/gpio/gpio$GPIO_RESETN/value
echo 1 > /sys/class/gpio/gpio$GPIO_PWRKEY/value
echo 0 > /sys/class/gpio/gpio$GPIO_PWRKEY/value
