#! /usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/.env"

# ---- Set Error Handling ----------
set -euo pipefail

# ---- Unmount Upon Interruption ----------
# Create unmount function
unmount()
{
	if [ -d "$mount_point" ]; then
		veracrypt --text --unmount "$mount_point"
		printf "Unmounted volume %s safely.\n" "$mount_point"
	fi
	if [ -d "$mount_point2" ]; then
		veracrypt --text --unmount "$mount_point2"
		printf "Unmounted volume %s safely.\n" "$mount_point2"
	fi
}

# Call unmount() upon error or interruption
trap unmount ERR INT

# ---- Mount Volume ----------
# mount volume(s)
veracrypt --text --pim=0 --keyfiles "" --protect-hidden=no --mount "$volume_path" "$mount_point"
veracrypt --text --pim=0 --keyfiles "" --protect-hidden=no --mount "$volume_path2" "$mount_point2"

# ---- Backup Files to Volume ----------
# create a versioning folder
mkdir -p "$mount_point/Versioning"

# create a run timestamp
timestamp="$(date +"%F-%H%M%S")"

# backup with rsync
for file in "${files[@]}"; do
	rsync \
		-axRS \
		--no-specials \
		--backup \
		--backup-dir \
		"$mount_point/Versioning" \
		--delete \
		--suffix=".$timestamp" \
		--exclude={'.Trashes','.TemporaryItems','.fseventsd','.Spotlight-V100'} \
		"$file" \
		"$mount_point"
done

# ---- Delete Archived Versions >90 Days Old ----------
if [ "$(find "$mount_point/Versioning" -type f -ctime +90)" != "" ]; then
	printf "Do you want to prune versions older than 90 days (y or n)? "
	read -r answer
	if [ "$answer" = "y" ]; then
		find "$mount_point/Versioning" -type f -ctime +90 -delete
		find "$mount_point/Versioning" -type d -empty -delete
	fi
fi

# ---- Update Log File ----------
printf "Add log entry (y or n)? "
read -r answer
if [ "$answer" = "y" ]; then
	printf "Add comment: "
	read -r comment
	printf "$timestamp\t%s\n" "$comment" >> "$mount_point/backups.log"
fi

# ---- Manually Inspect Backup ----------
open "$mount_point"
printf "Inspect backup and press enter "
read -r answer
unmount

# ---- Generate Hash of Backup ----------
printf "%s\n" "⚙️ Generating hash..."
openssl dgst -sha512 "$volume_path" > "$volume_path.sha512"

# ---- Generate Signature ----------
printf "%s\n" "⚙️ Generating signature..."
gpg --detach-sign -a --output "$volume_path.sha512.sig" "$volume_path.sha512"

# ---- Backup to Cloud ----------
printf "Upload to cloud (y or n)? "
read -r answer
if [ "$answer" = "y" ]; then
        printf "%s\n" "☁️  Uploading..."
        if proton-drive filesystem upload \
                "$volume_path" "$volume_path.sha512" "$volume_path.sha512.sig" \
                "/my-files/backup/" --file-conflict-strategy replace; then
                printf "%s\n" "✅ Uploaded to Proton Drive"
        else
                printf "%s\n" "⚠️  Proton Drive upload failed — local backup is still intact"
        fi
fi

# ---- FIN ----------
printf "%s\n" "✅ Success"
