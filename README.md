# Encrypted Backups with VeraCrypt and rsync on macOS

For context and instructions on how to create and use these scripts, visit my [project page](https://adamfurman.me/projects).

Purpose:
Credential management backup of sparsely-changing cryptographic keys, passwords, and TOTPs to a USB drive.

Tools:
- USB Drive
- VeraCrypt
- rsync
- Shell scripting
- macOS

> Project inspired by Sun Knudsen's [guide](https://github.com/sunknudsen/guides/tree/main/archive/how-to-back-up-and-encrypt-data-using-rsync-and-veracrypt-on-macos).

## backup.sh 

The `backup.sh` script mounts an encrypted VeraCrypt volume from a USB drive, backs up specified directories and files, prompts a manual check, creates a hash, and safely unmounts when finished.

## check.sh 

The `check.sh` runs an integrity check script that mounts an encrypted VeraCrypt volume from a USB drive, asks for the hash of your backup, compares it to the current hash of the volume, then outputs the result and unmounts the volume.

## restore.sh 

The `restore.sh` script mounts an encrypted VeraCrypt volume from a USB drive, opens the volume in finder, then unmounts.
