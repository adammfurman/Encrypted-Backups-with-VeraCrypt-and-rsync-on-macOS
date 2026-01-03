# Encrypted Backups with VeraCrypt and rsync on macOS

![Apple macOS](https://img.shields.io/badge/macOS-26.0-blue?logo=apple)
![signed commits](https://badgen.net/static/commits/signed/green?icon=github)

For context and instructions on how to create and use these scripts, visit my [project page](https://adamfurman.me/projects/encrypted-backups-with-veracrypt-and-rsync-on-macos/).

Purpose:
Credential management and secure backup of sparsely-changing cryptographic keys, passwords, and TOTPs to a USB drive.

Requirements:
- USB drive (or any storage media)
- macOS
- VeraCrypt
- rsync

> Project inspired by Sun Knudsen's [guide](https://github.com/sunknudsen/guides/tree/main/archive/how-to-back-up-and-encrypt-data-using-rsync-and-veracrypt-on-macos).

## example_env

Rename this file to ".env" and add your volume path, mount point, and backup files. 

## backup.sh 

The `backup.sh` script mounts an encrypted VeraCrypt volume from a USB drive, backs up specified directories and files, prompts a manual check, creates a hash, and safely unmounts when finished.

## check.sh 

The `check.sh` runs an integrity check script that mounts an encrypted VeraCrypt volume from a USB drive, asks for the hash of your backup, compares it to the current hash of the volume, then outputs the result and unmounts the volume.

## restore.sh 

The `restore.sh` script mounts an encrypted VeraCrypt volume from a USB drive, opens the volume in finder, then unmounts.
