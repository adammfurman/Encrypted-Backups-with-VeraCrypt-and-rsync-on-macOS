#! /usr/bin/env bash

# ---- Source Veriables ----------
source "$(dirname "$(readlink -f "$0")")/.env"

# ---- Set Error Handling ----------
set -euo pipefail

# set variables for text color
red=$(tput setaf 1)
green=$(tput setaf 2)
normal=$(tput sgr0)

# ---- Run Timestamp ----------
timestamp="$(date +"%F-%H%M%S")"

# ---- Backup Archive Names ----------
superbacked_file="${volume_path}.superbacked"
superbacked_hash="${superbacked_file}.sha512"
superbacked_signature="${superbacked_hash}.sig"

# ---- Unmount Upon Exit ----------
# Create unmount function
unmount()
{
	if [ -d "$mount_point" ]; then
		if veracrypt --text --unmount "$mount_point"; then
			printf "Unmounted volume %s safely.\n" "$mount_point"
		else
			printf "${red}WARNING: Failed to unmount %s.${normal}\n" "$mount_point" >&2
		fi
	fi

	if [ -d "$mount_point2" ]; then
		if veracrypt --text --unmount "$mount_point2"; then
			printf "Unmounted volume %s safely.\n" "$mount_point2"
		else
			printf "${red}WARNING: Failed to unmount %s.${normal}\n" "$mount_point2" >&2
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

# ---- Mount Volume(s) ----------
veracrypt --text --pim=0 --keyfiles "" --protect-hidden=no --mount "$volume_path" "$mount_point"
veracrypt --text --pim=0 --keyfiles "" --protect-hidden=no --mount "$volume_path2" "$mount_point2"

# ---- Backup Files to Volume ----------
printf "%s\n" "💾 Backing up files..."

# create a versioning folder
mkdir -p "$mount_point/Versioning"

# backup with rsync
for file in "${files[@]}"; do
	rsync \
		-axRS \
		--no-specials \
		--backup \
		--backup-dir="$mount_point/Versioning" \
		--delete \
		--suffix=".$timestamp" \
		--exclude={'.Trashes','.TemporaryItems','.fseventsd','.Spotlight-V100'} \
		"$file" \
		"$mount_point"
done

# ---- Delete Archived Versions >90 Days Old ----------
if [ "$(find "$mount_point/Versioning" -type f -mtime +90)" != "" ]; then
	printf "Do you want to prune versions older than 90 days (y or n)? "
	read -r answer
	if [ "$answer" = "y" ]; then
		find "$mount_point/Versioning" -type f -mtime +90 -delete
		find "$mount_point/Versioning" -type d -empty -delete
	fi
fi

# ---- Update Log File ----------
printf "Add log entry (y or n)? "
read -r answer
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
read -r answer
if [ "$answer" = "y" ]; then
	printf "%s\n" "📦 Creating Superbacked archive..."
	"$SUPERBACKED" create-standalone-archive \
		--force \
		--output "$superbacked_file" \
		"$mount_point"
	
	# ---- Generate Hash ----------
	printf "%s\n" "⚙️ Hashing archive..."
	openssl dgst -sha512 "$superbacked_file" > "$superbacked_hash"
	
	# ---- Generate GPG Signature ----------
	printf "%s\n" "🔏 Generating GPG signature, touch key..."
	gpg --detach-sign -a --output "$superbacked_signature" "$superbacked_hash"

	# ---- Verifying Hash ----------
	printf "%s\n" "🔎 Verifying SHA-512 hash..."
	expected_hash="$(awk '{print $NF}' "$superbacked_hash")" 
	actual_hash="$(openssl dgst -sha512 "$superbacked_file" | awk '{print $NF}')"

	if [ "$expected_hash" != "$actual_hash" ]; then
		printf "$(tput setaf 1)%s$(tput sgr0)\n" "SHA-512 verification failed"
		exit 1
	fi
	printf "$(tput setaf 2)%s$(tput sgr0)\n" "SHA-512 verified: $actual_hash"

	# ---- Verify GPG Signature ----------
	printf "%s\n" "🔎 Verifying GPG signature..."
	gpg --verify "$superbacked_signature" "$superbacked_hash"

	# ---- Upload ----------
	printf "%s\n" "☁️ Uploading to Proton Drive..."
	if proton-drive filesystem upload \
			"$superbacked_file" \
			"$superbacked_hash" \
			"$superbacked_signature" \
			"/my-files/" \
			--file-conflict-strategy replace; then
		printf "%s\n" "✅ Uploaded to Proton Drive"
	else
			printf "%s\n" "⚠️  Proton Drive upload failed — local backup is still intact"
	fi
	
	# --- Cleanup Files ----------
	if [ -f "$superbacked_file" ] &&
		[ -f "$superbacked_hash" ] &&
		[ -f "$superbacked_signature" ]; then

		rm -f \
			"$superbacked_file" \
			"$superbacked_hash" \
			"$superbacked_signature"
	fi
fi

# ---- Unmount Volumes ----------
unmount

# ---- Generate Hash of VeraCrypt Container ----------
printf "%s\n" "⚙️ Generating hash of VeraCrypt Container..."
openssl dgst -sha512 "$volume_path" > "$volume_path.sha512"

# ---- Generate Signature ----------
printf "%s\n" "⚙️ Generating signature..."
gpg --detach-sign -a --output "$volume_path.sha512.sig" "$volume_path.sha512"

# ---- FIN ----------
printf "%s\n" "✅ Backup completed successfully"
