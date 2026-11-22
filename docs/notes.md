# atomic-upgrade

## Guard layers

The system has two layers preventing accidental direct upgrades, controlled by a single `UPGRADE_GUARD` config flag (enabled by default):

**Pacman hook** (`atomic-guard`) — blocks `pacman -Syu` at the transaction level. Allows:
- Package installs without `--sysupgrade` (`pacman -S`, `-R`, etc.)
- Upgrades via `atomic-upgrade` (env var + lock verification)
- Upgrades via AUR helpers (`yay`, `paru`, `pikaur`, `aura`)

**Pacman wrapper** (`/usr/local/bin/pacman`) — intercepts `pacman -Syu` and suggests `atomic-upgrade` instead. Detects AUR helpers as parent processes to avoid double prompts. Also warns about `-Sy` without `-u` (partial upgrade risk).

Both layers check `UPGRADE_GUARD` at runtime — the change takes effect immediately, no restart or file removal needed.

### Disabling the guard

```bash
# /etc/atomic.conf
UPGRADE_GUARD=0
```

This disables both the pacman hook and the wrapper in a single setting. Files remain on disk but are bypassed. To re-enable, set back to `1` (or remove the line — default is `1`).

## Disk space checks

Before creating a snapshot, `atomic-upgrade` checks available disk space on both the Btrfs filesystem and the ESP:

- **Btrfs**: blocks only when free space is below the percentage threshold (default 10%) **and** below 2 GB absolute. On large disks where free percentage is low but tens of gigabytes are available, the operation proceeds with a warning.
- **ESP**: requires at least 250 MB free (one UKI is typically 200–230 MB).

If disk space cannot be determined (e.g. `btrfs` and `df` both fail), a warning is shown and the operation proceeds.

## Garbage collection

`atomic-gc` and the GC phase of `atomic-upgrade` keep the last N generations (default 3) plus the currently booted one. After deleting old generations, an orphan sweep removes:
- `root-*` subvolumes that have no matching UKI on the ESP
- UKI files on the ESP that have no matching subvolume

Orphan `home-*` subvolumes are reported but never auto-deleted. Use `btrfs subvolume delete` to remove them manually.

If the ESP is not mounted during the orphan sweep phase, it is skipped with a warning — orphans will be cleaned up on the next run.
