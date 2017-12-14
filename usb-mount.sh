#!/usr/bin/env bash
# If you are executing this script in cron with a restricted environment,
# modify the shebang to specify appropriate path; /bin/bash in most distros.
# And, also if you aren't comfortable using(abuse?) env command.

# This script is based on https://serverfault.com/a/767079 posted
# by Mike Blackwell, modified to our needs. Credits to the author.

# This script is called from systemd unit file to mount or unmount
# a USB drive.

PATH="$PATH:/usr/bin:/usr/local/bin:/usr/sbin:/usr/local/sbin:/bin:/sbin"
log="logger -t usb-mount.sh -s "

usage()
{
    ${log} "Usage: $0 {add|remove} device_name (e.g. sdb1)"
    exit 1
}

if [[ $# -ne 2 ]]; then
    usage
fi

ACTION=$1
DEVBASE=$2
DEVICE="/dev/${DEVBASE}"

# See if this drive is already mounted, and if so where
MOUNT_POINT=$(mount | grep ${DEVICE} | awk '{ print $3 }')

DEV_LABEL=""

do_mount()
{
    if [[ -n ${MOUNT_POINT} ]]; then
        ${log} "Warning: ${DEVICE} is already mounted at ${MOUNT_POINT}"
        exit 1
    fi

    # Get info for this drive: $ID_FS_LABEL, $ID_FS_UUID, and $ID_FS_TYPE
    eval $(blkid -o udev ${DEVICE})

    # Figure out a mount point to use
    LABEL=${ID_FS_LABEL}
    if grep -q " /media/${LABEL} " /etc/mtab; then
        # Already in use, make a unique one
        LABEL+="-${DEVBASE}"
    fi
    DEV_LABEL="${LABEL}"

    # Prefix the device name in case the drive doesn't have label
    MOUNT_POINT="/media/${DEVBASE}_${LABEL}"
    SMB_SHARE_NAME="${DEVBASE}_${LABEL}"

    ${log} "Mount point: ${MOUNT_POINT}"

    mkdir -p ${MOUNT_POINT}

    # Global mount options
    OPTS="rw,relatime"

    # File system type specific mount options
    if [[ ${ID_FS_TYPE} == "vfat" ]]; then
        OPTS+=",users,user,gid=65534,uid=65534,umask=000,shortname=mixed,utf8=1,flush"
    fi

    if ! mount -o ${OPTS} ${DEVICE} ${MOUNT_POINT}; then
        ${log} "Error mounting ${DEVICE} (status = $?)"
        rmdir "${MOUNT_POINT}"
        exit 1
    else
        # Track the mounted drives
        echo "${MOUNT_POINT}:${DEVBASE}" | cat >> "/var/log/usb-mount.track"
        ## 
        #Sharing mounted drive as public read write share if samba installed
	## 
	if [[ $(/usr/bin/which samba | grep -ic 'samba') != 0 ]]; then
		# Create samba file definition
		printf "[%s]\n  comment = Public share of %s\n  path = %s\n  browsable =yes\n  create mask = 0777\n  directory mask = 0777\n  writable = yes\n  guest ok = yes\n" "$SMB_SHARE_NAME" "$SMB_SHARE_NAME" "$MOUNT_POINT" > /etc/samba/${SMB_SHARE_NAME}.conf
		#Include samba file definition in smb.conf
		echo "include = /etc/samba/${SMB_SHARE_NAME}.conf" >> /etc/samba/smb.conf
		#restart smb service
		/bin/systemctl restart smbd
	fi
    fi

    ${log} "Mounted ${DEVICE} at ${MOUNT_POINT}"
}

do_unmount()
{
    if [[ -z ${MOUNT_POINT} ]]; then
        ${log} "Warning: ${DEVICE} is not mounted"
    else
        umount -l ${DEVICE}
	${log} "Unmounted ${DEVICE} from ${MOUNT_POINT}"
        /bin/rmdir "${MOUNT_POINT}"
        sed -i.bak "\@${MOUNT_POINT}@d" /var/log/usb-mount.track
        #
        #Remove samba share if exist
        #
        #Get name share
	SMB_SHARE_NAME=$(echo ${MOUNT_POINT} | sed "s/\/media\///g")
	if [ -f /etc/samba/${SMB_SHARE_NAME}.conf ]; then
		#Remove definition file
		/bin/rm /etc/samba/${SMB_SHARE_NAME}.conf
		#Remove include from smb.conf
		sed -i "s/include = \/etc\/samba\/${SMB_SHARE_NAME}.conf//g" /etc/samba/smb.conf
		#Delete all trailing blank lines at end of file 
		sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' /etc/samba/smb.conf
		#restart smb service
		/bin/systemctl restart smbd
	fi
    fi


}

case "${ACTION}" in
    add)
        do_mount
        ;;
    remove)
        do_unmount
        ;;
    *)
        usage
        ;;
esac
