# ComputerCleanup

**Tom de Leeuw / automatom — a Windows maintenance module with explicit cleanup choices, PowerShell confirmation, and disk-space reporting.**

This is the **unreleased 3.0.1-preview1 preparation build**. Automated checks use mocks and disposable synthetic files. Real Windows servicing, application recovery and disk-space acceptance still require a disposable VM. Licensing is pending; see [LICENSING.md](LICENSING.md). Do not substitute an older PowerShell Gallery package for this reviewed source.

## Purpose and scope

ComputerCleanup groups recurring Windows maintenance tasks into eight commands. An administrator selects the categories, previews their scope, approves execution, and receives structured results. No cleanup category runs by default.

The module is intended for a controlled maintenance window on a machine you administer, with users signed out and a recovery snapshot or backup. Deletion is permanent. Browser and Teams cleanup can close matching processes across user sessions. Downloads are personal data, and Recycle Bin cleanup removes a recovery option.

## Environment and permissions

- Windows only; Windows PowerShell 5.1 and PowerShell 7 on Windows are the compatibility targets. The source and isolated tests support both engines. Full runtime acceptance on Windows 11 and a supported Windows Server VM remains pending.
- Every public command requires an elevated administrator session, including previews. Importing the module does not require elevation or run cleanup.
- No external runtime PowerShell modules. Disk Cleanup requires an already installed `cleanmgr.exe`; the module does not install Windows components.
- User discovery covers physical directories beneath `$env:SystemDrive\Users`, excluding Administrator, Admin, Public and Default. It does not discover relocated profiles, FSLogix/profile containers, remote shares or every special account.
- Browser/Teams selection uses the registry detection rules in [CleanupTargets.json](CleanupTargets.json). Per-user installations can be missed, especially New Teams for another account. No automatic download or version discovery occurs.
- Quiesce applications and sessions first. Path checks avoid existing reparse points, but cannot eliminate races where another process swaps a path during an elevated cleanup. Live multi-user/RDS cleanup is outside this preparation build's acceptance scope.

## Load this source

From the reviewed project directory:

```powershell
Import-Module .\ComputerCleanup.psd1 -Force
Get-Command -Module ComputerCleanup
Get-Help Invoke-ComputerCleanup -Full
```

Start with a preview in the disposable VM:

```powershell
Invoke-ComputerCleanup -UserTemp -SystemTemp -Days 30 -WhatIf

# Only after inspecting the VM and taking a snapshot:
$results = Invoke-ComputerCleanup -UserTemp -SystemTemp -Days 30 -Confirm
$results | Format-Table
```

`-WhatIf` describes selected operations; it is **not an exhaustive file inventory or a byte estimate**. The orchestrator previews the batch and returns without starting a transcript, stopping processes/services, sending mail or invoking child cleanup. Individual commands preview their category or target directories. A preview still performs read-only prerequisite checks and can fail if a target/tool is unavailable.

`-Force` suppresses implicit confirmation. Explicit `-Confirm` takes precedence, and `-WhatIf -Force` never performs the selected operations. `-Confirm:$false` is intended for reviewed automation. Services are stopped, files removed and original services restored as a single approved transaction; restoration is not a second optional prompt.

## Commands and consequences

| Command | Selection and effect | Age filter |
|---|---|---|
| `Invoke-ComputerCleanup` | Runs only selected switches; returns one result per selected section and creates a transcript after approval | Passes `-Days` to user/system cleanup |
| `Optimize-UserProfiles` | `-TempFiles`; optional `-Downloads -ArchiveFiles` or `-GenericFiles` | Creation **and** last-write time must be older than cutoff |
| `Optimize-SystemFiles` | `-TempFiles`; optional current account's `-RecycleBin` on the system drive | Temp files only; Recycle Bin ignores age |
| `Clear-BrowserCache` | `-Browsers All,Chrome,Edge,IE,Firefox`; closes matching browser processes, clears configured cache paths | None |
| `Clear-TeamsCache` | Closes detected Teams processes; clears configured cache paths | None |
| `Clear-FontCache` | Stops FontCache, clears `FontCache-S-*.dat`, restores previously running service | None |
| `Clear-SoftwareDistribution` | Stops Windows Update/BITS, clears **contents** of `SoftwareDistribution\Download`, restores services | None |
| `Invoke-CleanManager` | Runs installed Disk Cleanup with a temporary unused preset; defaults to Temporary Files and Thumbnail Cache | Windows handler rules, not `-Days` |

System temp targets are Windows `Temp`, `Logs\CBS`, `Downloaded Program Files` and ProgramData `Microsoft\Windows\WER`. User temp targets are local WER, Internet Explorer Recovery, Terminal Server Client Cache, CrashDumps and Temp. The JSON file is the authoritative list of browser and Teams patterns. Existing cookies, DOMStore, WebCache databases, Firefox SQLite files and Teams local application databases/storage are excluded from this build's target definitions.

`-UserDownloads` on the orchestrator works independently of `-UserTemp`: it selects zip, rar, 7z and iso files **larger than 500 MB**, recursively under Downloads, subject to the age rule. Direct `Optimize-UserProfiles` supports numeric `-ArchiveSize` (default `500MB`) and `-GenericSize` (default `15MB`), and alphanumeric extension lists. The old quoted size strings have been replaced by byte counts. Files exactly at a size or date threshold are retained.

```powershell
# Synthetic maintenance examples: preview first, never real client paths.
Clear-BrowserCache -Browsers Chrome,Edge -WhatIf
Optimize-UserProfiles -Days 60 -Downloads -ArchiveFiles -ArchiveSize 1GB -WhatIf
Invoke-CleanManager -Sections 'Temporary Files','Thumbnail Cache' -WhatIf
```

Extra Disk Cleanup categories, such as `Update Cleanup`, `Previous Installations` and `Device Driver Packages`, require explicit selection through `-Sections`. They may remove rollback material. Do not run Windows Update or another Disk Cleanup process concurrently. `cleanmgr.exe` completion does not establish that every independently spawned servicing process has finished; verify the VM before measuring or restarting it.

## Safety and failure behavior

The shared deletion engine treats targets literally, checks all existing ancestors for reparse points, and enumerates directories one level at a time on both engines. It deletes eligible files individually and only removes empty descendant directories nonrecursively. Target directories are retained. A stale parent never authorizes deletion of a recent child. Junctions, volume roots, UNC paths and parent traversal are refused or skipped.

Locked/inaccessible files produce errors. The orchestrator uses terminating errors for child failures and stops the batch. Service stop failure aborts deletion and attempts rollback of any partial stop; a `finally` block restores originally running services after cleanup failure. Originally stopped services stay stopped. Recovery failures are surfaced and need operator attention. No rollback of deleted files is available.

SoftwareDistribution cleanup no longer renames into `Download.old`, recursively removes that folder, or runs `robocopy /MIR`. An existing `Download.old` is left alone. Disk Cleanup preserves pre-existing StateFlags presets and removes only its temporary flags in `finally`.

## Reports, logging and privacy

Results contain `Name`, `Duration`, `SpaceBeforeGB`, `SpaceAfterGB`, `SpaceCleanedGB` and `IsPreview`. Disk readings use the system drive. `SpaceCleanedGB` is an observed free-space delta rounded to 0.01 GB, **not a verified total of deleted bytes**. Concurrent disk activity can make it negative; do not sum overlapping measurements or claim measured savings from synthetic tests. Preview results report zero and `IsPreview = true`; the orchestrator itself emits no result objects for a skipped/preview batch.

Approved orchestrator runs create a unique transcript under `$env:SystemRoot\Temp`. Only a successfully started transcript is stopped, including when a child fails. Logs can contain local paths, usernames and machine details. Keep them private and apply your own retention policy.

Legacy `-MailReport` remains opt-in and requires `-SmtpServer`, `-SmtpPort`, `-FromAddress` and `-ToAddress`; it has a separate confirmation. It uses obsolete `Send-MailMessage`, with no TLS/authentication configuration in this module. Use it only with an explicitly trusted relay. Prefer routing the returned objects through your approved reporting system. No mail is sent by tests or previews.

## Development and validation

```powershell
Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser
Install-Module PSScriptAnalyzer -RequiredVersion 1.24.0 -Scope CurrentUser
.\tools\Test-Local.ps1 -ResultsPath .\test-results\local.xml
```

Run that script in both `powershell.exe` and `pwsh.exe`. It checks parsing, manifest entries, eight exports, warning/error-free source analysis, and Pester safety tests. Tests mock Windows administration and create only disposable synthetic files; an isolated host answers No to explicit confirmations. No administrator rights are needed for those tests. CI runs the same checks on Windows Server 2022 with both engines and scans source/history for secrets. It has no publishing or deployment job.

See [VM acceptance](docs/VM-ACCEPTANCE.md), [security guidance](SECURITY.md), [contribution guidance](CONTRIBUTING.md), [changes](CHANGELOG.md), and the [portfolio case-study draft](docs/PORTFOLIO-CASE-STUDY.md).
