#! /bin/sh
source $(dirname "$(readlink -f "$0")")/.env

# ---- Set Error Handling ----------
set -euo pipefail

# Create unmount function
function unmount()
{
	if [ -d "$mount_point" ]; then
		veracrypt --text --unmount "$mount_point"
	fi
}

# Call unmount() upon error or interruption
trap unmount ERR INT

# ---- Restore ----------
# Mount volume
veracrypt --text --mount --mount-options "readonly" --pim "0" --keyfiles "" --protect-hidden "no" "$volume_path" "$mount_point"

# Restore data
open "$mount_point"
printf "Restore data and press enter"
read -r answer

# unmount
unmount

# ---- FIN ----------
printf "%s\n" "Done"
