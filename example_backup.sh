#! /bin/sh

# ---- Set Error Handling ----------
set -euo pipefail

# ---- Unmount Upon Interruption ----------
# Create unmount function
function unmount()
{
	if [ -d "$mount_point" ]; then
		veracrypt --text --unmount "$mount_point"
		printf "Unmounted volume safely.\n"
	fi
}

# Call unmount() upon error or interruption
trap unmount ERR INT

# ---- Mount Volume ----------
# set path variables
volume_path="/Volumes/[MEDIA]/[DIRECTORY]" # CHANGE TO YOUR DIRECTORY
mount_point="/Volumes/[Backup]" # CHANGE TO YOUR VOLUME NAME

# mount volume
veracrypt --text --mount --pim "0" --keyfiles "" --protect-hidden "no" "$volume_path" "$mount_point"

# ---- Backup Files to Volume ----------
# create a versioning folder
mkdir -p "$mount_point/Versioning"

# specify files to backup here
files=(
	"/YOUR/PATH/TO/DIRECTORY"
	"/YOUR/PATH/TO/FILE"
)

# backup with rsync
for file in "${files[@]}"; do
	rsync \
		-axRS \
		--no-specials \
		--backup \
		--backup-dir \
		"$mount_point/Versioning" \
		--delete \
		--suffix="$(date +".%F-%H%M%S")" \
		"$file" \
		"$mount_point"
done

# ---- Delete Archived Versions >90 Days Old ----------
if [ "$(find "$mount_point/Versioning" -type f -ctime +90)" != "" ]; then
	printf "Do you want to prune versions older than 90 days (y or n)? "
	read -r answer
	if [ "$answer" = "y" ]; then
		find "$mount_point/Versioning" -type f -ctime +90 -delete
		find "$mount_point.Versioning" -type d -empty -delete
	fi
fi

# ---- Manually Inspect Backup ----------
open "$mount_point"
printf "Inspect backup and press enter "
read -r answer
unmount

# ---- Generate Hash of Backup ----------
printf "Generate hash (y or n)? "
read -r answer
if [ "$answer" = "y" ]; then
	printf "%s\n" "⚙️ Generating…"
	openssl dgst -sha512 "$volume_path"
fi

# ---- FIN ----------
printf "%s\n" "✅ Success"
