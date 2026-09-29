#! /usr/bin/env bash

# ---- Set Error Handling ----------
set -euo pipefail

# set variables for term color
red=$(tput setaf 1)
green=$(tput setaf 2)
normal=$(tput sgr0)

# ---- Source Variables ----------
source "$(dirname "$(readlink -f "$0")")/.env"

# ---- Run Timestamp ----------
timestamp="$(date +"%F-%H%M%S")"

# ---- Backup Archive Names ----------
superbacked_file="${volume_path}.superbacked"
superbacked_signature="${superbacked_file}.sig"

# ---- Unmount Upon Exit ----------
# Create unmount function
unmount()
{
	if [ -d "$mount_point" ]; then
		if veracrypt --text --unmount "$mount_point"; then
			printf "Unmounted volume %s safely.\n" "$mount_point"
		else
			printf "%sWARNING: Failed to unmount %s.%s\n" "$red" "$mount_point" "$normal" >&2
		fi
	fi

	if [ -d "$mount_point2" ]; then
		if veracrypt --text --unmount "$mount_point2"; then
			printf "Unmounted volume %s safely.\n" "$mount_point2"
		else
			printf "%sWARNING: Failed to unmount %s.%s\n" "$red" "$mount_point2" "$normal" >&2
		fi
	fi
}

# Cleanup function calls unmount() and exits
cleanup()
{
	local exit_status=$?
	unmount
	exit "$exit_status"
}

# Call cleanup() upon exit, interruption, errrors, and termination
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ---- Check Required Commands ----------
for cmd in rsync openssl gpg veracrypt proton-drive "$superbacked"; do
	if ! command -v "$cmd" > /dev/null 2>&1; then
		printf "%sERROR: Required command not found: %s%s\n" "$red" "$cmd" "$normal" >&2
		exit 1
	fi
done

# ---- Mount Volume(s) ----------
veracrypt --text --pim=0 --keyfiles "" --protect-hidden=no --mount "$volume_path" "$mount_point"
veracrypt --text --pim=0 --keyfiles "" --protect-hidden=no --mount "$volume_path2" "$mount_point2"

# ---- Backup Files to Volume ----------
printf "%s\n" "💾 Backing up files..."

# create a versioning and logs folder
if [ -d "$mount_point" ]; then
	mkdir -p "$mount_point/Versioning" "$mount_point/Logs"
fi

# backup with rsync
for file in "${files[@]}"; do
	rsync \
		-axRS \
		--no-specials \
		--backup \
		--backup-dir="$mount_point/Versioning" \
		--suffix=".$timestamp" \
		--delete \
		--exclude={'.Trashes','.TemporaryItems','.fseventsd','.Spotlight-V100'} \
		--log-file="$mount_point/Logs/rsync.log" \
		--log-file-format="%-5o %f %C" \
		--quiet \
		"$file" \
		"$mount_point"
done

# ---- Rotate Logs ----------
log="$mount_point/Logs/rsync.log"
max_size=262144  # 256 KiB in bytes

# rotate log file if greater than max_size, up to 4 total files
if [ -f "$log" ] && [ "$(stat -f "%z" "$log")" -ge "$max_size" ]; then
	rm -f "${log}.3"
	for i in 2 1; do
		[ -f "${log}.${i}" ] && mv "${log}.${i}" "${log}.$((i+1))"
	done
	mv "$log" "${log}.1"
fi

# ---- Delete Archived Versions >90 Days Old ----------
if [ "$(find "$mount_point/Versioning" -type f -mtime +90)" != "" ]; then
	printf "Do you want to prune versions older than 90 days (y or n)? "
	read -r answer || answer=n
	if [ "$answer" = "y" ]; then
		find "$mount_point/Versioning" -type f -mtime +90 -delete
		find "$mount_point/Versioning" -type d -empty -delete
	fi
fi

# ---- Update Log File ----------
printf "Add log entry (y or n)? "
read -r answer || answer=n
if [ "$answer" = "y" ]; then
	printf "Add comment: "
	read -r comment
	printf "%s\t%s\n" "$timestamp" "$comment" >> "$mount_point/backups.log"
fi

# ---- Manually Inspect Backup ----------
open "$mount_point"
printf "Inspect backup and press enter "
read -r answer

# ---- Backup to Cloud ----------
printf "Upload to cloud (y or n)? "
read -r answer || answer=n
if [ "$answer" = "y" ]; then
	printf "%s\n" "📦 Creating Superbacked archive..."
	"$superbacked" create-standalone-archive \
		--force \
		--output "$superbacked_file" \
		"$mount_point"
	
	# ---- Generate GPG Signature ----------
	printf "%s\n" "🔏 Generating GPG signature, touch key..."
	gpg --detach-sign -a --output "$superbacked_signature" "$superbacked_file"

	# ---- Verify GPG Signature ----------
	printf "%s\n" "🔎 Verifying GPG signature..."
	gpg --verify "$superbacked_signature" "$superbacked_file"

	# ---- Upload ----------
	printf "%s\n" "☁️ Uploading to Proton Drive..."
	if proton-drive filesystem upload \
			"$superbacked_file" \
			"$superbacked_signature" \
			"/my-files/" \
			--file-conflict-strategy replace; then
		printf "%s\n" "✅ Uploaded to Proton Drive"
	else
			printf "%s%s%s\n" "$red" "⚠️  Proton Drive upload failed — local backup is still intact" "$normal"
	fi
	
	# --- Cleanup Files ----------
	if [ -f "$superbacked_file" ] && [ -f "$superbacked_signature" ]; then
		rm -f "$superbacked_file" "$superbacked_signature"
	fi
fi

# ---- Unmount Volumes ----------
unmount

# ---- Generate Hash of VeraCrypt Container ----------
printf "%s\n" "⚙️ Generating hash of VeraCrypt container..."
openssl dgst -sha512 "$volume_path" > "$volume_path.sha512"

# ---- Generate Signature ----------
printf "%s\n" "🔏 Generating signature..."
gpg --detach-sign -a --output "$volume_path.sha512.sig" "$volume_path.sha512"

# ---- FIN ----------
printf "%s\n" "✅ Backup completed successfully"
