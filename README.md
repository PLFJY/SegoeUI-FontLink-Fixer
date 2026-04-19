# SegoeUI-FontLink-Fixer

`SegoeUI-FontLink-Fixer` is a conservative PowerShell tool for inspecting, backing up, previewing, applying, verifying, and restoring Windows FontLink mappings for the `Segoe UI` family.

It targets:

`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink`

The main use case is correcting CJK fallback priority for `Segoe UI*` values on systems where the default order is not a good fit for the user's preferred Chinese, Japanese, or Korean fallback behavior.

The tool does **not** rebuild FontLink lists from scratch. It uses a stable reordering strategy:

- move matching target-language fonts earlier
- preserve unrelated entries in their original order
- avoid inventing entries that do not already exist on the machine

## Safety Warning

This project edits `HKLM` registry data. That is sensitive system configuration.

Please read the script and understand the risks before using `apply` or `restore`.

Important safety behavior:

- no registry write happens before backup succeeds
- every write path validates inputs before proceeding
- `apply` verifies the registry after writing and does not report success if verification fails
- `restore` validates the selected backup, creates a fresh pre-restore safety backup, restores the snapshot, and verifies the final registry state
- incomplete backup directories are marked and rejected

This reduces risk, but does not remove it. Use it only if you are comfortable recovering registry settings.

## Features

- backs up the entire `SystemLink` key, not just selected `Segoe UI*` values
- exports both a `.reg` file and a structured JSON snapshot
- writes a manifest with hashes and inventory data for validation
- processes every registry value whose name starts with `Segoe UI`
- also manages `Tahoma` and `Microsoft Sans Serif` conservatively
- supports `zh-CN`, `zh-TW`, `ja-JP`, and `ko-KR` language profiles
- supports dry-run preview mode
- supports restoring the latest valid backup or a specific backup path
- includes a keyboard-driven TUI for local use
- supports interface languages:
  `en-US`, `zh-CN`, `zh-TW`, `ja-JP`, `ko-KR`

## Requirements

- Windows
- PowerShell 5.1 or later
- administrator rights for `apply` and `restore`

## Quick Start

Launch the TUI:

```powershell
.\SegoeLinker.ps1
```

Or explicitly:

```powershell
.\SegoeLinker.ps1 tui
```

Run a dry-run preview:

```powershell
.\SegoeLinker.ps1 apply zh-CN --dry-run
```

Create a manual backup:

```powershell
.\SegoeLinker.ps1 backup
```

Restore the latest valid backup:

```powershell
.\SegoeLinker.ps1 restore --latest
```

## TUI

Running `.\SegoeLinker.ps1` opens the local TUI.

The TUI is designed as the primary human-facing interface:

- main menu choices react to a single key press
- profile selection reacts to a single key press
- language selection reacts to a single key press
- free-text prompts are only used when input is inherently textual, such as a restore path

The TUI stores the selected interface language in a local settings file:

- `.segoelinker.user.json`

That file is kept in the project directory and ignored by Git.

## Interface Languages

You can switch UI language inside the TUI, or use `--lang` from the command line.

If no `--lang` is provided, the tool uses the locally saved language preference from `.segoelinker.user.json` when available.

Examples:

```powershell
.\SegoeLinker.ps1 list --lang zh-CN
.\SegoeLinker.ps1 status --lang ja-JP
.\SegoeLinker.ps1 backup --lang ko-KR
.\SegoeLinker.ps1 tui --lang zh-TW
```

Supported language IDs:

- `en-US`
- `zh-CN`
- `zh-TW`
- `ja-JP`
- `ko-KR`

## Commands

```powershell
.\SegoeLinker.ps1
.\SegoeLinker.ps1 tui
.\SegoeLinker.ps1 backup
.\SegoeLinker.ps1 apply zh-CN
.\SegoeLinker.ps1 apply ja-JP --dry-run
.\SegoeLinker.ps1 restore --latest
.\SegoeLinker.ps1 restore --file .\backups\20260420-120000123
.\SegoeLinker.ps1 list
.\SegoeLinker.ps1 status
.\SegoeLinker.ps1 help
```

## Supported Profiles

- `zh-CN`: prioritize `Microsoft YaHei UI`, `Microsoft YaHei`
- `zh-TW`: prioritize `Microsoft JhengHei UI`, `Microsoft JhengHei`
- `ja-JP`: prioritize `Yu Gothic UI`, `Yu Gothic`, `Meiryo UI`, `Meiryo`
- `ko-KR`: prioritize `Malgun Gothic`

Profile behavior is intentionally conservative:

- only existing matching entries are moved
- unrelated entries keep their relative order
- missing fonts are not added automatically

Additional legacy UI behavior:

- `Segoe UI*`, `Tahoma`, and `Microsoft Sans Serif` are all handled with the same stable reordering model
- only entries already present in a value are moved
- no `,128,96` legacy entries are synthesized for values that do not already contain them

## Backup Format

Each backup is stored in a timestamped directory under [backups](./backups).

A completed backup contains:

- `SystemLink.reg`
  full `reg.exe export` output for compatibility with manual inspection
- `SystemLink.snapshot.json`
  structured snapshot of the full target key for exact restore logic
- `manifest.json`
  schema version, timestamps, file hashes, registry path, and value inventory

The tool marks in-progress backups with `backup.incomplete.txt`. If backup creation fails at any point, that directory remains unusable for restore by design.

## Restore Model

`restore` is designed to be explicit and defensive.

The flow is:

1. resolve the requested backup with `--latest` or `--file`
2. validate the manifest, required files, schema version, registry target, and hashes
3. create a new safety backup of the current registry state
4. restore the full `SystemLink` snapshot exactly
5. verify that the post-restore registry state matches the snapshot

The restore is exact at the `SystemLink` key level:

- values present in the backup are restored
- values currently present but absent from the backup snapshot are removed

That exactness is intentional, because partial merge restore logic is riskier for this use case.

## Elevation

`apply` and `restore` require administrator rights because they write to `HKLM`.

The script checks elevation before write operations. If needed, it relaunches itself with elevation before any registry modification begins.

The elevation path was designed specifically to avoid fragile manual command-line string concatenation. Arguments are passed through an encoded bootstrap payload so paths with spaces and complex arguments are preserved more safely.

Commands that do not require forced elevation:

- `backup`
- `list`
- `status`
- `apply --dry-run`
- `tui`

Inside the TUI, write actions still route through the same safe command path.

## Output and Verification

The tool prints:

- elevation state
- backup location
- matching managed values
- preview before/after order
- which backup is selected for restore
- verification success or failure
- a reminder that logoff or reboot may be required

The tool does **not** claim success after `apply` or `restore` unless verification passes.

## Failure Cases That Stop Execution

The tool stops instead of continuing when it sees conditions such as:

- invalid profile ID
- missing `--file` path
- invalid backup selection
- incomplete backup marker present
- missing manifest, snapshot, or `.reg` export
- backup hash mismatch
- wrong registry target in backup metadata
- unsupported registry value kinds in restore snapshot
- `Segoe UI*` values of an unexpected type
- post-write verification mismatch

## Notes

- `status` shows the current `Segoe UI*` values plus `Tahoma` and `Microsoft Sans Serif`, along with the latest valid backup
- `list` shows supported profiles and their priority fonts
- the TUI stores the selected language locally in `.segoelinker.user.json`
- changes may require logoff, reboot, or target application restart before they become visible
- the `backups/` directory is ignored by Git except for `.gitkeep`
- `.segoelinker.user.json` is ignored by Git

## Limitations

- this tool only reorders existing entries; it does not synthesize missing FontLink data
- if an `apply` operation fails partway through writing, the pre-write backup is available, but rollback is still a separate deliberate action
- interactive TUI behavior is intended for a local console session, not unattended automation
- single-key menu handling depends on a local console; when that is unavailable, PowerShell may fall back to line-based input

## Disclaimer

This project aims to be careful, but it still changes sensitive registry settings. Review the code, understand the recovery path, and do not apply changes blindly.
