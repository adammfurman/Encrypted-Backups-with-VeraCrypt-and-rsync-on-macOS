#! /bin/sh
# ---- Set Error Handling ----------
set -euo pipefail

# ---- Integrity Verification ----------
# set variables for text color
red=$(tput setaf 1)
normal=$(tput sgr0)

# Ask for previous hash
# include the full output (i.e. SHA2-512(<Backup path>)= <hash>)
printf "Enter backup hash: "
read -r previous
printf "⚙️ Checking hashes…\n"
current=$(openssl dgst -sha512 "/Volumes/YOUR_VERACRYPT_VOLUME_PATH")

# Compare hashes
if [ "$current" != "$previous" ]; then
	printf "$red%s$normal\n" "Integrity check failed"
	exit 1
fi

printf "%s\n" "✅ Verified OK"
