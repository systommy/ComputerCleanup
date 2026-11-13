# Changelog

## 3.0.1-preview1 — unreleased

- Licensed under MIT (owner decision, 13 November 2026); added LICENSE, manifest LicenseUri and FileList entry.
- Reconciled current GitHub and archive source; restored required JSON definitions omitted from an earlier preparation snapshot. Preserved module GUID and eight public commands; updated personal credits and repository URL.
- Guarded browser/Teams shutdown with ShouldProcess; explicit Confirm overrides Force. Added WhatIf support inside deletion, process, service and logging helpers.
- Replaced recursive deletion with literal, reparse-aware traversal and file-level age/size rules. Empty directories are removed nonrecursively. New files survive stale parents.
- Switched user cleanup from last-access to last-write age; size parameters are numeric bytes. Downloads works independently of UserTemp. Invalid extensions are rejected.
- Made service operations fail closed, roll back partial stops and restore original running services in finally. Removed SoftwareDistribution rename/Download.old/robocopy fallback.
- Removed Disk Cleanup auto-installation, narrowed default categories, used temporary unused presets, and cleaned up registry flags on failure. Rollback-related categories require explicit selection.
- Removed application databases/local storage from browser and Teams cache defaults.
- Stopped logging and email in previews. Transcript lifecycle now uses finally; SMTP validation occurs before cleanup. Kept legacy email opt-in.
- Added preview labeling and system-drive accounting, fail-fast import, isolated safety tests, Windows CI, secret scans, operator guidance and VM acceptance gates.

Compatibility changes are intentional: High confirmation for deletion commands; reduced cleanup scope; numeric size parameters; last-write age; no auto-installed Disk Cleanup; errors stop orchestrated work instead of concealing partial failure. Real servicing behavior remains subject to VM acceptance.
