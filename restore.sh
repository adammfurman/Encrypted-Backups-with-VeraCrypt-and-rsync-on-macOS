#! /bin/sh
source $(dirname "$(readlink -f "$0")")/.env

# ---- Set Error Handling ----------
set -euo pipefail

# Create unmount function
unmount()
{
	local exit_status=$?

	if [ -d "$mount_point" ]; then
		veracrypt --text --unmount "$mount_point"
	fi
	if [ -d "$mount_point2" ]; then
		veracrypt --text --unmount "$mount_point2"
	fi

	exit "$exit_status"
}

# Call unmount() upon error or interruption
trap unmount EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ---- Restore ----------
# Mount volume
veracrypt --text --mount --mount-options "readonly" --pim=0 --keyfiles "" --protect-hidden "no" "$volume_path" "$mount_point"
veracrypt --text --mount --mount-options "readonly" --pim=0 --keyfiles "" --protect-hidden "no" "$volume_path2" "$mount_point2"

# Restore data
open "$mount_point"
printf "Restore data and press enter"
read -r answer

# ---- FIN ----------
printf "%s\n" "Done"
