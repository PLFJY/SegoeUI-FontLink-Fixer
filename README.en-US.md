# SegoeUI-FontLink-Fixer

[简体中文](README.md) / [日本語](README.ja-JP.md) / [한국어](README.ko-KR.md) / English

> [!WARNING]
> A substantial portion of this project's code was generated with AI assistance and then iterated on through ongoing manual work, integration testing, and refactoring, but it may still contain omissions, incomplete edge-case handling, or behavior that does not fully match expectations.
> If you encounter bugs, compatibility issues, unexpected behavior, or missing documentation, please open an Issue. Reproduction steps, logs, screenshots, and OS version details would be especially helpful.

`SegoeUI-FontLink-Fixer` is a conservative, safety-first PowerShell tool for inspecting, backing up, previewing, applying, verifying, and restoring Windows FontLink registry mappings.

Target registry path:

`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink`

Its main purpose is to adjust fallback priority for `Segoe UI*`, `Tahoma`, and `Microsoft Sans Serif` when the default CJK fallback order is not a good fit for the user's preferred behavior.

## What It Does

This tool does not rebuild FontLink lists from scratch. It uses a stable reordering model:

- move only target-language fonts earlier
- preserve the relative order of unrelated entries
- never invent entries that are not already present in the current value

It is meant for cautious order correction, not aggressive reconstruction.

## Safety Warning

This project edits system registry data under `HKLM`. That is sensitive configuration.

Before using `apply` or `restore`, read the scripts and make sure you understand the risks and recovery path.

Current safety behavior:

- every write path requires a successful backup first
- execution stops immediately after a backup failure
- `apply` re-reads the registry and verifies the written data before reporting success
- `restore` validates the selected backup, creates a fresh pre-restore safety backup, restores the snapshot, and verifies the final state
- incomplete backups are explicitly marked and rejected

These safeguards reduce risk, but they do not remove it.

## Features

- backs up the entire `SystemLink` key
- exports both a `.reg` file and a structured JSON snapshot
- writes `manifest.json` with hashes, timestamps, and value inventory
- processes every value whose name starts with `Segoe UI`
- also processes `Tahoma` and `Microsoft Sans Serif`
- supports `zh-CN`, `zh-TW`, `ja-JP`, and `ko-KR`
- supports dry-run / preview mode
- supports restoring the latest valid backup or a specific backup path
- includes a local keyboard-driven TUI
- supports UI languages:
  `zh-CN`, `ja-JP`, `ko-KR`, `en-US`

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

Preview a profile:

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

The TUI is intended to be the main interface for human users:

- single-key main menu
- single-key profile selection
- single-key language selection
- text input only when text is inherently required, such as a restore path

The selected UI language is stored in:

- `.segoelinker.user.json`

That file is written to the project root and ignored by Git.

## UI Languages

You can switch languages inside the TUI or use `--lang` on the command line.

If `--lang` is not provided, the tool will use the locally saved UI language when available.

Examples:

```powershell
.\SegoeLinker.ps1 list --lang zh-CN
.\SegoeLinker.ps1 status --lang ja-JP
.\SegoeLinker.ps1 backup --lang ko-KR
.\SegoeLinker.ps1 tui --lang en-US
```

Supported language IDs:

- `zh-CN`
- `ja-JP`
- `ko-KR`
- `en-US`

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

The behavior is intentionally conservative:

- only matching entries already present in a value are moved
- unrelated entries keep their relative order
- missing font entries are not added automatically

Additional notes:

- `Segoe UI*`, `Tahoma`, and `Microsoft Sans Serif` all use the same stable reordering model
- only existing entries are moved earlier
- no `,128,96` entries are synthesized for values that do not already contain them

## Backup Format

Each backup is stored in a timestamped directory under [backups](./backups).

A complete backup contains:

- `SystemLink.reg`
  full `reg.exe export` output for manual inspection and manual import compatibility
- `SystemLink.snapshot.json`
  structured snapshot for exact restore behavior
- `manifest.json`
  schema version, timestamps, file hashes, registry path, and value inventory

The tool writes `backup.incomplete.txt` while a backup is in progress. If backup creation fails, that directory remains intentionally unusable for restore.

## Restore Model

`restore` is designed to be explicit, conservative, and verifiable.

Flow:

1. resolve the target backup with `--latest` or `--file`
2. validate the manifest, required files, schema version, target registry path, and hashes
3. create a fresh safety backup of the current state
4. restore the full `SystemLink` snapshot exactly
5. re-read the registry and verify that it matches the snapshot

Restore is exact at the `SystemLink` key level:

- values present in the backup are restored
- values present now but missing from the backup are removed

That choice is intentional because partial merge restore logic is riskier here.

## Elevation

`apply` and `restore` require administrator rights because they write to `HKLM`.

The script checks elevation before any write operation. If needed, it relaunches itself with elevation before continuing.

Argument passing for elevation uses an encoded payload instead of fragile manual command-line concatenation, which is safer for paths with spaces, quotes, and Unicode arguments.

Commands that do not force elevation by default:

- `backup`
- `list`
- `status`
- `apply --dry-run`
- `tui`

Write actions launched from the TUI still use the same safe execution path.

## Output and Verification

The tool clearly prints:

- current elevation state
- backup location
- matching managed values
- before/after preview differences
- selected backup during restore
- verification success or failure
- reminder that logoff or reboot may be needed

The tool does not claim success after `apply` or `restore` unless verification passes.

## Conditions That Stop Execution

Execution stops instead of continuing when it encounters conditions such as:

- invalid profile ID
- missing `--file` path
- invalid backup selection
- incomplete backup marker present
- missing manifest, snapshot, or `.reg` file
- backup hash mismatch
- wrong backup target registry path
- unsupported registry value kinds in a restore snapshot
- target value is not `MultiString`
- post-write verification mismatch

## Notes

- `status` shows `Segoe UI*`, `Tahoma`, `Microsoft Sans Serif`, and the latest valid backup
- `list` shows supported profiles and their target fonts
- the TUI stores the selected UI language in `.segoelinker.user.json`
- changes may require logoff, reboot, or application restart before they fully take effect
- `backups/` is ignored by Git except for `.gitkeep`
- `.segoelinker.user.json` is ignored by Git

## Limitations

- this tool only reorders existing entries; it does not synthesize missing FontLink data
- if `apply` fails partway through, the pre-write backup exists, but rollback is still a separate explicit action
- the TUI is meant for a local interactive console, not unattended automation
- when immediate key reading is not available, the TUI falls back to line-input compatibility mode

## Disclaimer

This project is designed to be careful, but it still changes sensitive system registry settings. Review the code, understand the recovery path, and do not apply changes blindly.
