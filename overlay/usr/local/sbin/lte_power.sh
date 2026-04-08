#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause

GPIO_PWRKEY="5d090000.gpio 12"

gpioget ${GPIO_PWRKEY}

# Power-On Sequence:
# - enable vbat (handled by kernel)
# - deassert reset (handled by kernel)
# - toggle power key
gpioset ${GPIO_PWRKEY}=0
sleep 0.5
gpioset ${GPIO_PWRKEY}=1
