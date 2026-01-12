#! /bin/sh
source $(dirname "$(readlink -f "$0")")/.env

# ---- Set Error Handling ----------
set -euo pipefail

# Create unmount function
unmount()
{
	if [ -d "$mount_point" ]; then
		veracrypt --text --unmount "$mount_point"
	fi
	if [ -d "$mount_point2" ]; then
		diskutil quiet unmount "$mount_point2"
	fi
}

# Call unmount() upon error or interruption
trap unmount ERR INT

# ---- Restore ----------
# Mount volume
veracrypt --text --mount --mount-options "readonly" --pim "0" --keyfiles "" --protect-hidden "no" "$volume_path" "$mount_point"
diskutil quiet image attach "$volume_path2"

# Restore data
open "$mount_point"
printf "Restore data and press enter"
read -r answer

# unmount
unmount

# ---- FIN ----------
printf "%s\n" "Done"
