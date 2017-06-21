#!/bin/bash
#/* Copyright 2017 NXP
# */

# This script will be used to disable the services on ls2088
# board in order to take performance numbers

systemctl stop systemd-timesyncd.service > /dev/null 2>&1
systemctl stop time-sync.target > /dev/null 2>&1
systemctl stop timers.target > /dev/null 2>&1
systemctl stop ureadahead-stop.timer > /dev/null 2>&1

service apparmor stop > /dev/null 2>&1
service console-setup stop > /dev/null 2>&1
service ebtables stop > /dev/null 2>&1
service keyboard-setup stop > /dev/null 2>&1
service kmod stop > /dev/null 2>&1
service networking stop > /dev/null 2>&1
service procps stop > /dev/null 2>&1
service qemu-kvm stop > /dev/null 2>&1
service resolvconf stop > /dev/null 2>&1
service udev stop > /dev/null 2>&1
service urandom stop > /dev/null 2>&1
service web-sysmon.sh stop > /dev/null 2>&1
service cgmanager stop > /dev/null 2>&1
service cpufrequtils stop > /dev/null 2>&1
service cron stop > /dev/null 2>&1
service docker stop > /dev/null 2>&1
service dbus stop > /dev/null 2>&1
service libvirt-bin stop > /dev/null 2>&1
service libvirt-guests stop > /dev/null 2>&1
service lm-sensors stop > /dev/null 2>&1
service loadcpufreq stop > /dev/null 2>&1
service lxcfs stop > /dev/null 2>&1
service mountdebugfs stop > /dev/null 2>&1
service netperf stop > /dev/null 2>&1
service nginx stop > /dev/null 2>&1
service ondemand stop > /dev/null 2>&1
service rc.local stop > /dev/null 2>&1
service rsyslog stop > /dev/null 2>&1
service setkey stop > /dev/null 2>&1
service ssh stop > /dev/null 2>&1
service sysfsutils stop > /dev/null 2>&1
service sysstat stop > /dev/null 2>&1
service ubuntu-fan stop > /dev/null 2>&1
service vsftpd stop > /dev/null 2>&1
service udev stop > /dev/null 2>&1
