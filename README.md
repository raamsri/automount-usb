### Automount USB drives with systemd

On inserting an USB drive, automounts the drive at /media/ as a
directory named by the device name suffixed with the device label; just
the device name if label is empty: /media/sdd\_usbtest, /media/sdd\_

Tracks the list of mounted drives in /var/log/usb-mount.track
Logs the actions in /var/log/messages with tag 'usb-mount.sh'

Please do not expect it to perfectly handle all your needs.
Be warned, trivially tested; okay for temporary plug-ins but definitely
not recommended for enclosures with longer TTL.

**To setup, run ./CONFIGURE.sh with sudo or as root; REMOVE.sh to undo the
setup.**
