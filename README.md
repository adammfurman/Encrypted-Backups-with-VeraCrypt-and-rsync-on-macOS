# Encrypted Backups with VeraCrypt and rsync on macOS

![Apple macOS](https://img.shields.io/badge/macOS-26.0-blue?logo=apple)
![signed commits](https://badgen.net/static/commits/signed/green?icon=github)
![PGP signatures](https://img.shields.io/badge/PGP%20signatures-verified-0093DD?logo=gnuprivacyguard)

For context and instructions on how to create and use these scripts, visit my [write-up](https://adamfurman.me/posts/encrypted-backups-with-veracrypt-and-rsync-on-macos/).

Purpose:
Credential management and secure backup of sparsely-changing cryptographic keys, passwords, and TOTPs to a USB drive.

Requirements:
- USB drive (or any storage media)
- macOS
- VeraCrypt
- rsync
- b3sum (Blake3 hash commandline utility)

> Project inspired by Sun Knudsen's [guide](https://github.com/sunknudsen/guides/tree/main/archive/how-to-back-up-and-encrypt-data-using-rsync-and-veracrypt-on-macos).

## Features

- 3 scripts for backup, integrity verification, and restoring files
- Clean unmount for errors and interruptions
- Versioning keeps a history of any changed or replaced files
- Prune capability deletes versioned files after 90 days
- Logging tracks each backup with a timestamp and comment
- Integrity verification using BLAKE3 for fast volume hashing

## example_env

Rename `example_env` to `.env` and add your volume path, mount point, and backup files.

```
mv example_env .env
``` 

## backup.sh 

The `backup.sh` script mounts an encrypted VeraCrypt volume from a USB drive, backs up specified directories and files, prompts a manual check, creates a hash, and safely unmounts when finished.

## check.sh 

The `check.sh` runs an integrity check script that mounts an encrypted VeraCrypt volume from a USB drive, asks for the hash of your backup, compares it to the current hash of the volume, then outputs the result and unmounts the volume.

## restore.sh 

The `restore.sh` script mounts an encrypted VeraCrypt volume from a USB drive, opens the volume in finder, then unmounts.

## Signatures

You can verify each script with my [PGP public key](https://github.com/adammfurman/pgp-public-key) to confirm authenticity and integrity.

```
gpg --verify signatures/backup.sh.asc backup.sh
```
