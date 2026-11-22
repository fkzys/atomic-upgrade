# atomic-upgrade

## Configuration

Edit `/etc/atomic.conf`:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `BTRFS_MOUNT` | `/run/atomic/temp_root` | Btrfs top-level mount point |
| `NEW_ROOT` | `/run/atomic/newroot` | New snapshot mount point |
| `ESP` | `/efi` | EFI System Partition |
| `KEEP_GENERATIONS` | `3` | Generations to keep (excluding current) |
| `MAPPER_NAME` | `root_crypt` | dm-crypt mapper name (fallback if auto-detection fails) |
| `KERNEL_PKG` | `linux` | Kernel package (linux/linux-lts/linux-zen) |
| `KERNEL_PARAMS` | *(security defaults)* | Kernel command line parameters |
| `CHROOT_COMMAND` | `/usr/bin/pacman -Syu` | Default command in snapshot chroot (overrides built-in `pacman -Syu`) |
| `SBCTL_SIGN` | `0` | Sign UKI files with sbctl for Secure Boot (`0`=off, `1`=on) |
| `UPGRADE_GUARD` | `1` | Upgrade guard: block direct `pacman -Syu` (`0`=off, `1`=on) |
| `HOME_COPY_FILES` | *(empty)* | Files to copy into isolated home subvolumes (see [Home isolation](#home-isolation)) |

> **Config syntax:** inline comments start at ` #` (space then hash).
> Values containing a literal ` #` sequence will be truncated. This does not
> affect typical paths or kernel parameters.

Default `KERNEL_PARAMS`: `rw slab_nomerge init_on_alloc=1 page_alloc.shuffle=1 pti=on vsyscall=none randomize_kstack_offset=on debugfs=off`

Root device is auto-detected (LUKS, LVM, LUKS+LVM, plain Btrfs). `MAPPER_NAME` is only used as a fallback if auto-detection fails.

### Secure Boot signing

UKI signing with `sbctl` is **disabled by default**. To enable:

1. Set up Secure Boot with sbctl (enroll keys, etc.)
2. Install `sbctl` if not already installed
3. Enable in config:

```bash
# /etc/atomic.conf
SBCTL_SIGN=1
```

When disabled, UKI files are built unsigned. They will boot on systems with Secure Boot disabled or in setup mode.

### Example: TPM2 auto-unlock

```bash
KERNEL_PARAMS="rd.luks.options=tpm2-device=auto rw slab_nomerge init_on_alloc=1 page_alloc.shuffle=1 pti=on vsyscall=none randomize_kstack_offset=on debugfs=off"
```
### Shell completion

Tab completion is available for `atomic-gc`, `atomic-rebuild-uki`, and `atomic-upgrade` in both zsh and bash:

Completions are installed automatically. For bash, the `bash-completion` package must
be installed and sourced in `~/.bashrc`:

```bash
# ~/.bashrc
[[ -r /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion
```

For zsh, completions are picked up automatically after restarting the shell.

### AUR helpers

AUR helpers (`yay`, `paru`, etc.) are allowed through the pacman hook guard
but by default run on the **live system**, not atomically. A warning is shown
when this happens.

**Recommended: run AUR helper inside the snapshot**

```bash
sudo atomic-upgrade -- sudo -u YOUR_USER yay -Syu
```

This creates a snapshot, chroots into it, and runs `yay -Syu` as your regular
user — updating both official and AUR packages atomically in a single generation.

Replace `YOUR_USER` with your username and `yay` with your AUR helper of choice.

**Installing a specific AUR package atomically:**

```bash
sudo atomic-upgrade -t my-pkg -- sudo -u YOUR_USER yay -S my-aur-package
```

**Multiple commands:**

```bash
sudo atomic-upgrade -- bash -c '/usr/bin/pacman -Syu && sudo -u YOUR_USER yay -S pkg1 pkg2'
```

> **Note:** If you run `yay -Syu` directly (outside `atomic-upgrade`), the
> upgrade applies to the live system and is **not atomic**. The next
> `atomic-upgrade` will snapshot whatever state the live system is in.

## Home isolation

> This feature is not for permanent environments.
> Permanent setups should use regular generations with the shared `/home` subvolume.

`--separate-home` creates an isolated `/home` subvolume for the generation — so
experiments with dotfiles, DE configs, or user-level packages don't pollute your
main home. If something goes wrong, delete the generation and the home subvolume
is orphaned; GC will warn you about it.

```bash
# Try KDE
sudo atomic-upgrade --separate-home -t kde -- pacman -S plasma-meta

# Bring specific dotfiles
sudo atomic-upgrade --separate-home -t dev --copy-files ".bashrc .ssh .gitconfig" -- pacman -S base-devel

# Dry run to preview
sudo atomic-upgrade --dry-run --separate-home -t test
```

**How it works:**

1. A new Btrfs subvolume `home-TAG` is created (or reused if it already exists)
2. User directories are created with correct ownership (users with UID ≥ 1000)
3. Files listed in `--copy-files` (or `HOME_COPY_FILES` from config) are copied from
   current `/home/<user>/` into the new home
4. The generation's fstab is updated so `/home` points to the new subvolume

**Constraints:**

- Requires `--tag` (the home subvolume is named `home-TAG`)
- `--copy-files` requires `--separate-home`
- File paths with spaces are not supported
- Absolute paths and `..` traversal are rejected for safety

**Cleanup:** GC never auto-deletes home subvolumes.
When all generations referencing a tag are gone, GC reports the orphan:

```
   Orphan home: home-kde (no generations with tag 'kde')
   To remove: btrfs subvolume delete /run/atomic/temp_root/home-kde
```

A default set of files to copy can be configured:

```bash
# /etc/atomic.conf
HOME_COPY_FILES=".bashrc .bash_profile .ssh .gnupg .gitconfig"
```

The `--copy-files` flag overrides `HOME_COPY_FILES` per invocation.
