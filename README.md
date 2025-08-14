# Bsecret
---
A script I use to encrypt secrets repos via gpg directly or via sops.

pro tip: dont use this, use git secret or somehting.


## Usage
---
A .gitsecret must be specified.

The first line should either be:

- TYPE=SOPS
- TYPE=GPG

If SOPS is specified, no secret file patterns need to be defined as the patterns will be read from the `.sops.yaml` file.

If GPG is specified, each line after the first will be treated as a secret file regex pattern. 
