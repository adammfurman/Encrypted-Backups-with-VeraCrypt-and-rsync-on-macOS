#! /usr/bin/env bash

# ---- Set Error Handling ----------
set -euo pipefail

# ---- Set Terminal Output Variables ----------
red=$(tput setaf 1 2>/dev/null || true)
green=$(tput setaf 2 2>/dev/null || true)
normal=$(tput sgr0 2>/dev/null || true)

# ---- Run Timestamp ----------
timestamp="$(date +"%F %H:%M:%S")"	# for logs
run_id="$(date +%FT%H%M%S)"			# for versioning suffix

# ---- Helper Functions ----------
# print an error in red and exit
fail()
{
	printf "%sERROR: %s%s\n" "$red" "$1" "$normal" >&2
	exit 1
}


# ---- Source env file ----------
env_file="$(dirname "$(readlink -f "$0")")/.env"

# check if .env exists
if [ ! -f "$env_file" ]; then
	fail ".env not found at $env_file"
fi

source "$env_file"

# ---- Check Required Variables ----------
for var in volume_path mount_point volume_path2 mount_point2 superbacked; do
	if [ -z "${!var:-}" ]; then
		fail "Missing variables in .env: $var"
	fi
done

# check if files declared
if ! declare -p files > /dev/null 2>&1 || [ "${#files[@]}" -eq 0 ]; then
	fail "No files listed in .env"
fi

# ---- Unmount Upon Exit ----------
# check if directory is mounted
# compares the device id to the parent, should have different id if mounted
is_mounted()
{
	[ -d "$1" ] && [ "$(stat -f "%d" "$1")" != "$(stat -f "%d" "$1/..")" ]
}

# Create unmount function
unmount()
{
	local mp
	for mp in "${mount_point:-}" "${mount_point2:-}"; do
		if [ -n "$mp" ] && is_mounted "$mp"; then
			if veracrypt --text --unmount "$mp"; then
				printf "Unmounted volume %s safely.\n" "$mp"
			else
				printf "%sWARNING: Failed to unmount %s.%s\n" "$red" "$mp" "$normal" >&2
			fi
		fi
	done
}

# Cleanup function calls unmount(), removes temp files, and exits
work_dir=""
cleanup()
{
	local exit_status=$?
	set +e
	unmount
	if [ -n "$work_dir" ] && [ -d "$work_dir" ]; then
		rm -rf -- "$work_dir"
	fi
	exit "$exit_status"
}

# Call cleanup() upon exit, interruption, errrors, and termination
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ---- Check Required Commands ----------
for cmd in rsync openssl gpg veracrypt proton-drive "$superbacked"; do
	if ! command -v "$cmd" > /dev/null 2>&1; then
		fail "Required command not found: $cmd"
	fi
done

# ---- Mount Volume(s) ----------
veracrypt --text --pim=0 --keyfiles "" --protect-hidden=no --mount "$volume_path" "$mount_point"
if ! is_mounted "$mount_point"; then
	fail "$mount_point is not a mounted volume"
fi

veracrypt --text --pim=0 --keyfiles "" --protect-hidden=no --mount-options=ro --mount "$volume_path2" "$mount_point2"
if ! is_mounted "$mount_point2"; then
	fail "$mount_point2 is not a mounted volume"
fi

# ---- Backup Files to Volume ----------
printf "%s\n" "💾 Backing up files..."

# create a versioning and logs folder
mkdir -p "$mount_point/Versioning" "$mount_point/Logs"

# backup with rsync
for file in "${files[@]}"; do
	# check if source files exist
	if [ ! -e "$file" ]; then
		fail "Source missing: $file"
	fi
	# check if source directory is not empty
	if [ -d "$file" ] && [ -z "$(ls -A "$file" 2>/dev/null)" ]; then
		fail "Source directory is empty: $file"
	fi

	# sync files
	rsync \
		-axRS \
		--no-specials \
		--backup \
		--backup-dir="$mount_point/Versioning" \
		--suffix=".$run_id" \
		--delete \
		--exclude={'.Trashes','.TemporaryItems','.fseventsd','.Spotlight-V100','.DS_Store'} \
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
		if [ -f "${log}.${i}" ]; then
			mv "${log}.${i}" "${log}.$((i+1))"
		fi
	done
	mv "$log" "${log}.1"
fi

# ---- Delete Archived Versions >90 Days Old ----------
if [ "$(find "$mount_point/Versioning" -type f -mtime +90)" != "" ]; then
	printf "\nDo you want to prune versions older than 90 days (y or n)? "
	read -r answer || answer=n
	if [ "$answer" = "y" ]; then
		find "$mount_point/Versioning" -type f -mtime +90 -delete
		find "$mount_point/Versioning" -type d -empty -delete
	fi
fi

# ---- Update Log File ----------
printf "📝 Log comment (Enter to skip): "
read -r comment || comment=""
if [ -n "$comment" ]; then
	printf "%s\t%s\n" "$timestamp" "$comment" >> "$mount_point/backups.log"
fi


# ---- Manually Inspect Backup ----------
open "$mount_point"
printf "Inspect backup and press enter "
read -r answer || true

# ---- Backup to Cloud ----------
printf "Upload to cloud (y or n)? "
read -r answer || answer=n
if [ "$answer" = "y" ]; then
	work_dir="$(mktemp -d "${TMPDIR:-/tmp}/secrets-backup.XXXXXX")"
	superbacked_archive="$work_dir/$(basename "$volume_path").superbacked"
	superbacked_signature="${superbacked_archive}.sig"
	
	printf "%s\n" "📦 Creating Superbacked archive..."
	"$superbacked" create-standalone-archive \
		--yubikey \
		--force \
		--output "$superbacked_archive" \
		"$mount_point"
	
	# ---- Generate GPG Signature ----------
	printf "%s\n" "🔏 Generating GPG signature, touch key..."
	gpg --detach-sign -a --output "$superbacked_signature" "$superbacked_archive"

	# ---- Verify GPG Signature ----------
	printf "%s\n" "🔎 Verifying GPG signature..."
	gpg --verify "$superbacked_signature" "$superbacked_archive"

	# ---- Upload ----------
	printf "%s\n" "☁️ Uploading to Proton Drive..."
	if proton-drive filesystem upload \
			"$superbacked_archive" \
			"$superbacked_signature" \
			"/my-files/" \
			--file-conflict-strategy replace; then
		printf "%s\n" "✅ Uploaded to Proton Drive"
	else
		printf "%s%s%s\n" "$red" "⚠️  Proton Drive upload failed, local backup is still intact" "$normal"
	fi
	
	# --- Cleanup Files ----------
	rm -rf -- "$work_dir"
	work_dir=""
fi

# ---- Unmount Volumes ----------
unmount
if is_mounted "$mount_point" || is_mounted "$mount_point2"; then
	fail "A volume is still mounted, not hashing the container"
fi

# ---- Generate Hash of VeraCrypt Container ----------
printf "%s\n" "⚙️ Generating hash of VeraCrypt container..."
openssl dgst -sha512 "$volume_path" > "$volume_path.sha512"

# ---- Generate Signature ----------
printf "%s\n" "🔏 Signing hash, touch key..."
gpg --yes --detach-sign -a --output "$volume_path.sha512.sig" "$volume_path.sha512"

# ---- FIN ----------
printf "%s\n" "✅ Backup completed successfully"
