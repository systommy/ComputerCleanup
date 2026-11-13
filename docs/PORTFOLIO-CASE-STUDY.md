# Portfolio case study draft

**Suggested repository description:** Windows maintenance module with explicit cleanup selection, PowerShell previews and confirmations, guarded file deletion, service recovery, and structured disk-space reports.

**Title:** Making Windows cleanup reviewable

**Problem.** Temporary files and application caches accumulate across Windows machines and user profiles. Ad hoc cleanup scripts can hide their scope, terminate active applications, follow unexpected directory links or delete newer files because a parent folder looks old.

**Solution.** Tom de Leeuw built ComputerCleanup as a PowerShell module with focused commands and an optional orchestrator. Administrators choose the categories and preview the operation. A shared file engine applies age and size rules to individual files, rejects reparse paths and only removes empty directories. Service operations preserve original running state and attempt recovery after failures.

**Practical value.** The code demonstrates repeatable maintenance workflows, explicit risk boundaries, error handling and testable automation. Synthetic regression tests cover both successful cleanup and failures, including cancellation, stale-parent/new-child behavior, junctions and partial service stops. Structured output lets operators integrate results into their own reporting process.

**What visitors can inspect.** Source code, safety tests, configuration, documented compatibility changes and a disposable VM acceptance checklist. After VM acceptance, add a synthetic WhatIf transcript and a clearly labeled before/after disk measurement with its method and limitations.

**Limits.** This is an unreleased preparation build, not a claim of production certification. Application/version detection is incomplete; profile containers and active multi-user environments are outside the acceptance scope. Disk deltas can include unrelated activity. Real servicing/application-recovery evidence and a deliberate license decision are still required. No client data, client screenshots or invented performance numbers belong in the published story.
