#!/usr/bin/env bash
# If you are executing this script in cron with a restricted environment,
# modify the shebang to specify appropriate path; /bin/bash in most distros.
# And, also if you aren't comfortable using(abuse?) env command.
PATH="$PATH:/usr/bin:/usr/local/bin:/usr/sbin:/usr/local/sbin:/bin:/sbin"

# Just a best effort
rm -f /usr/local/bin/usb-mount.sh

# Systemd unit file for USB automount/unmount 
rm -f /etc/systemd/system/usb-mount@.service

# Remove the track files
rm -f /var/log/usb-mount.track*

# Remove udev rule
sed -i "/systemctl\sstart\susb-mount/d" /etc/udev/rules.d/99-local.rules
sed -i "/systemctl\sstop\susb-mount/d" /etc/udev/rules.d/99-local.rules

systemctl daemon-reload
udevadm control --reload-rules
