#! /bin/sh
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
veracrypt --text --mount --pim "0" --keyfiles "" --protect-hidden "no" "$volume_path" "$mount_point"
veracrypt --text --mount --pim "0" --keyfiles "" --protect-hidden "no" "$volume_path2" "$mount_point2"

# ---- Backup Files to Volume ----------
# create a versioning folder
mkdir -p "$mount_point/Versioning"

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
	printf "$(date +%F' '%T)\t%s\n" "$comment" >> "$mount_point/backups.log"
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
	printf "%s\n" "⚙️ Generating..."
	# openssl dgst -sha256 "$volume_path"
	b3sum "$volume_path" > "$volume_path.b3"
fi

# ---- Generate Signature ----------
printf "Generate signature (y or n)? "
read -r answer
if [ "$answer" = "y" ]; then
	gpg --detach-sign -a --output "$volume_path.b3.sig" "$volume_path.b3"
fi

# ---- FIN ----------
printf "%s\n" "✅ Success"
