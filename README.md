# atomic-upgrade

[![CI](https://github.com/fkzys/atomic-upgrade/actions/workflows/ci.yml/badge.svg)](https://github.com/fkzys/atomic-upgrade/actions/workflows/ci.yml)
![License](https://img.shields.io/github/license/fkzys/atomic-upgrade)
[![Spec](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/fkzys/specs/refs/heads/main/version.json&maxAge=300)](https://github.com/fkzys/specs)

Atomic system upgrades for Arch Linux on Btrfs + UKI + optional Secure Boot.

NixOS/Silverblue-style generational updates on plain Arch: Btrfs snapshot → chroot → upgrade → build UKI → sign → reboot. Rollback is selecting a previous UKI entry in the boot menu.

## Docs

- **[usage](docs/usage.md)**
    - [Configuration](docs/usage.md#configuration)
        - [Secure Boot signing](docs/usage.md#secure-boot-signing)
        - [Example: TPM2 auto-unlock](docs/usage.md#example-tpm2-auto-unlock)
        - [AUR helpers](docs/usage.md#aur-helpers)
    - [Home isolation](docs/usage.md#home-isolation)
- **[notes](docs/notes.md)**
    - [Guard layers](docs/notes.md#guard-layers)
        - [Disabling the guard](docs/notes.md#disabling-the-guard)
    - [Disk space checks](docs/notes.md#disk-space-checks)
    - [Garbage collection](docs/notes.md#garbage-collection)

## How it works

```
sudo atomic-upgrade
        ↓
  1. Btrfs snapshot of current root
  2. Mount snapshot, chroot into it
  3. Run command (default: pacman -Syu)
  4. Verify snapshot consistency (kernel, initramfs, modules)
  5. Update fstab (subvol=)
  6. Build UKI (ukify)
  7. Sign with sbctl (if SBCTL_SIGN=1)
  8. Garbage collect old generations
        ↓
  reboot → new generation active
```

Rollback: select a previous UKI entry in the boot menu.

Each generation is a snapshot + UKI pair. The UKI contains the kernel and initramfs from that snapshot, and its cmdline points to that specific subvolume. Rollback works because each boot menu entry maps to one complete system state.

## Prerequisites

- Btrfs root filesystem on a subvolume (any name — snapshots are created as `root-<timestamp>`)
- A bootloader or UEFI firmware that discovers UKI files (Type #2 entries) — systemd-boot, rEFInd, direct UEFI boot, etc.
- Optional secure boot with sbctl.

The tool places `.efi` files into `ESP/EFI/Linux/` (signed or unsigned depending on `SBCTL_SIGN`). Any boot environment that picks up UKI files from that path should work.

> `/home`, `/var/log`, `/var/cache`, and other stateful data
> should live on separate Btrfs subvolumes. Only the root subvolume is
> snapshotted and rolled back.

Example layout:
> ```bash
> ➜  lt --level 1
> .
> ├── home
> ├── log
> ├── cache
> ├── root-20261025-224514
> ├── root-20261104-001419
> ├── root-20261113-153925
> ├── root-20261116-181747 # here it's current gen
> └── snapshots
> ```

Then you struct your root skeleton with `/etc/fstab`:
```bash
/dev/mapper/root_crypt	/	        btrfs	[your options here],subvol=/root-20261116-181747	0 0
# it's probably works when the line above is
# absent but i don't want to test if it's true

/dev/mapper/root_crypt	/var/log	btrfs	[your options here],subvol=/log	0 0

/dev/mapper/root_crypt	/var/cache	btrfs	[your options here],subvol=/cache	0 0

/dev/mapper/root_crypt	/snapshots	btrfs	[your options here],subvol=/snapshots	0 0
```

## Installation

### AUR

```bash
yay -S atomic-upgrade
```

### gitpkg
```bash
gitpkg install atomic-upgrade
```

### Manual

```bash
git clone https://github.com/fkzys/atomic-upgrade.git
cd atomic-upgrade
sudo make install
```

## Usage

```bash
sudo atomic-upgrade
sudo atomic-upgrade --dry-run
sudo atomic-upgrade -t pre-nvidia                      # custom tag
sudo atomic-upgrade --no-gc                            # without garbage collection
sudo atomic-upgrade -- pacman -S nvidia                # specific package
sudo atomic-upgrade -t nvidia -- pacman -S nvidia-dkms # command with tag
sudo atomic-upgrade --no-gc -t cleanup -- pacman -Rns firefox
sudo atomic-gc                                         # clean old generations (keep last 3 + current)
sudo atomic-gc --dry-run 2                             # preview: keep last 2
atomic-gc list
sudo atomic-gc rm 20260217-143022                      # delete specific generation
sudo atomic-gc rm -y 20260217-143022 20260216-235122   # delete multiple without confirmation
sudo atomic-gc activate 20260217-143022                # mark as active (UEFI boots first)
sudo atomic-gc deactivate 20260217-143022
sudo atomic-gc protect 20260217-143022                 # protect from gc
sudo atomic-gc unprotect 20260217-143022
sudo atomic-rebuild-uki --list                         # show subvolumes and UKI status
sudo atomic-rebuild-uki 20250208-134725                # rebuild UKI for specific generation
```

### Example run

```
:: Current: /root-20260220-141710 → New: /root-20260221-010551
:: Command: /usr/bin/pacman -Syu
:: Verifying current system...
:: Verifying current subvolume...
:: Checking disk space...
   Disk space: 76% free (~365GB)
   ESP space: 763MB free
:: Creating snapshot...
:: Mounting new root...
:: Running: /usr/bin/pacman -Syu
   [... pacman output ...]
:: Verifying snapshot consistency...
:: Updating fstab...
:: Building UKI...
Wrote unsigned /efi/EFI/Linux/arch-20260221-010551.efi
:: Signing UKI for Secure Boot...
✓ Signed /efi/EFI/Linux/arch-20260221-010551.efi
:: Unmounting new root...
:: Verifying signature...
✓ /efi/EFI/Linux/arch-20260221-010551.efi is signed
:: Running garbage collection...
:: Garbage collecting (keeping last 3 + current)...
   Keeping: 20260221-010551
   Keeping: 20260220-141710 (current)
   Keeping: 20260216-235122
   Keeping: 20260212-202715
:: Garbage collection done
Generation 20260221-010551 ready. Reboot to activate.
```

## Troubleshooting

### fstab uses `subvolid=` without `subvol=`

`atomic-upgrade` requires a `subvol=` option in the root fstab entry to track which generation is active. If your fstab uses only `subvolid=`, add `subvol=/your-current-subvol` to the mount options:

```bash
# Before:
UUID=xxx / btrfs [your options],subvolid=256 0 0

# After:
UUID=xxx / btrfs [your options],subvolid=256,subvol=/root-20260601-120000 0 0
```

> **Note:** When both `subvolid=` and `subvol=` are present, some kernels prioritize `subvolid=`. Consider removing `subvolid=` from fstab.

### Low disk space warning on large disks

On disks larger than ~200 GB, the free percentage may drop below 10% while absolute free space is still well above 2 GB.
In this case `atomic-upgrade` shows a warning but proceeds normally, operation will be blocked when both the percentage and absolute thresholds are crossed.

## Dependencies

Installed automatically via the AUR package:
- [`verify-lib`](https://github.com/fkzys/verify-lib) — validates shell libs before sourcing
- `btrfs-progs`
- `systemd-ukify`
- `python`

Optional:
- `sbctl` — Secure Boot
- `cryptsetup`
- `lvm2`
- `bash-completion`

## License

AGPL-3.0-or-later
