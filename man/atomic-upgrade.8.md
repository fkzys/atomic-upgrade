---
title: ATOMIC-UPGRADE
section: 8
header: System Administration
footer: atomic-upgrade
---

# NAME

atomic-upgrade — atomic system upgrades for Arch Linux on Btrfs

# SYNOPSIS

**atomic-upgrade** [**-n**|**\--dry-run**] [**-t**|**\--tag** *TAG*] [**\--no-gc**] [**\--** *COMMAND*...]

**atomic-rebuild-uki** [**-l**|**\--list**] *GEN_ID*

# DESCRIPTION

**atomic-upgrade** creates a Btrfs snapshot of the current root subvolume,
mounts it, runs a command inside an arch-chroot (default: **pacman -Syu**),
updates *fstab*, builds a Unified Kernel Image (UKI), optionally signs it
with **sbctl**(8), and runs garbage collection.

The new generation becomes active on next reboot. Rollback is performed by
selecting a previous UKI entry in systemd-boot.

**atomic-rebuild-uki** rebuilds the UKI for an existing generation subvolume.
Use it to recover an accidentally deleted *.efi* file.

# OPTIONS

**-n**, **\--dry-run**
:   Show what would be done without making changes. For the default
    **pacman -Syu** command, also prints available upgrades.

**-t**, **\--tag** *TAG*
:   Append *TAG* to the generation timestamp. Only letters, numbers,
    hyphens, and underscores are allowed (max 48 characters).
    Example: **-t pre-nvidia** creates *root-20260317-213728-pre-nvidia*.

**\--no-gc**
:   Skip garbage collection after a successful upgrade.

**\--** *COMMAND*...
:   Run *COMMAND* in the snapshot chroot instead of the default
    **pacman -Syu**.

**-h**, **\--help**
:   Show usage summary and exit.

**-V**, **\--version**
:   Show version and exit.

# UPGRADE GUARD

Two guard layers prevent accidental direct system upgrades, controlled by the
**UPGRADE_GUARD** option in **atomic.conf**(5) (enabled by default).

**Pacman hook** (**atomic-guard**)
:   A pre-transaction hook that blocks **pacman -Syu** unless called from
    **atomic-upgrade** (verified via environment variable and file lock) or
    from an AUR helper (**yay**, **paru**, **pikaur**, **aura**). Package
    installs, removals, and queries are never blocked.

**Pacman wrapper** (*/usr/local/bin/pacman*)
:   Intercepts **pacman -Syu** and prompts the user to use **atomic-upgrade**
    instead. In non-interactive contexts (piped stdin), it aborts for safety.
    Also warns when **-Sy** is used without **-u** (partial upgrade risk).

Both layers read **UPGRADE_GUARD** at runtime — changing the value in
**atomic.conf**(5) takes effect immediately.

When an AUR helper is detected in the process tree, the hook allows the
transaction but prints a warning that the upgrade runs on the live system
and is not atomic.

# DISK SPACE CHECKS

Before creating a snapshot, the following checks are performed:

- **Btrfs**: the operation is blocked only when free space is below the
  percentage threshold (default 10%) **and** below 2 GB absolute. On large
  disks with low percentage but sufficient absolute free space, a warning is
  shown and the operation proceeds.
- **ESP**: requires at least 250 MB free.

If space cannot be determined, a warning is shown and the operation proceeds.

# EXIT STATUS

**0**
:   Success.

**1**
:   Error. Common causes: missing dependencies, insufficient disk space,
    lock held by another instance, chroot command failure, UKI build failure,
    fstab update failure.

# ENVIRONMENT

**ATOMIC_UPGRADE**
:   Set to **1** by **atomic-upgrade** before invoking pacman. Used by
    **atomic-guard** to verify the caller. Should not be set manually.

**CONFIG_FILE**
:   Override path to the configuration file (default: */etc/atomic.conf*).
    Intended for testing.

**LOCK_FILE**
:   Override path to the lock file (default: */var/lock/atomic-upgrade.lock*).
    Intended for testing.

# FILES

*/etc/atomic.conf*
:   Configuration file. See **atomic.conf**(5).

*/usr/lib/atomic/common.sh*
:   Shared shell library.

*/usr/lib/atomic/fstab.py*
:   Safe fstab manipulation (atomic write, verification, rollback).

*/usr/lib/atomic/rootdev.py*
:   Root device auto-detection and kernel cmdline generation.

*/var/lock/atomic-upgrade.lock*
:   Exclusive lock file preventing concurrent operations.

*/efi/EFI/Linux/arch-\*.efi*
:   Unified Kernel Images, one per generation.

# EXAMPLES

Standard system upgrade:

    sudo atomic-upgrade

Preview without changes:

    sudo atomic-upgrade --dry-run

Install a specific package atomically:

    sudo atomic-upgrade -- pacman -S nvidia-dkms

Run AUR helper inside the snapshot:

    sudo atomic-upgrade -- sudo -u myuser yay -Syu

Upgrade with a custom tag:

    sudo atomic-upgrade -t pre-nvidia

Rebuild a missing UKI:

    sudo atomic-rebuild-uki 20250208-134725

List subvolumes and UKI status:

    sudo atomic-rebuild-uki --list

# SEE ALSO

**atomic-gc**(8), **atomic.conf**(5), **btrfs-subvolume**(8), **ukify**(1),
**sbctl**(8), **pacman**(8), **arch-chroot**(8), **systemd-boot**(7)
