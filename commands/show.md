---
description: "Show local project artifacts and task bookkeeping; acceptance and live status are not assessed."
scripts:
  sh: scripts/bash/status.sh
  ps: scripts/powershell/status.ps1
---

# Project Status

Show a read-only overview of local Spec Kit artifacts. Task checkboxes are
bookkeeping, not evidence of engineering acceptance or permission to implement.

## User Input

```text
$ARGUMENTS
```

Consider nonempty input as a feature selector, such as `003` or `003-media`.
Append `--feature "003"` to the Bash script command or `-Feature "003"` to the
PowerShell script command, replacing `003` with the supplied selector as one
quoted argument. With no input, append no feature flag; the script resolves the
environment/branch or returns the all-feature summary.
Do not interpolate user input as shell code.

## Outline

1. Execute `{SCRIPT}` from the project root. Parse its single JSON document;
   on a nonzero exit, present the JSON error rather than inferring a feature.
2. Present project name, detected agents and commands/skills, script type,
   Git branch, and selected `feature_name` (under `specs/`).
3. Explain selection: explicit argument overrides `SPECIFY_FEATURE`, which
   overrides a numbered `NNN-...` Git branch. An exact directory wins; otherwise
   the three-digit prefix must match exactly one directory. Missing or ambiguous
   selections fail. Main, detached HEAD, or no Git without a selector produce
   an all-feature summary with `phase: no_feature`; never choose the latest.
4. Show artifact existence for spec, plan, tasks, research, data model,
   quickstart, contracts and checklists. Checklist status is only checkbox
   bookkeeping. Fenced Markdown examples do not count.
5. Show checked/total tasks and the reported local phase:
   - `not_started`: no specification.
   - `plan`: specification exists, plan absent.
   - `tasks`: plan exists, task file absent.
   - `no_tasks`: task file exists without actionable checkboxes.
   - `implement`: at least one task remains unchecked; verify authorization.
   - `tasks_checked`: all task checkboxes checked; acceptance remains unassessed.
6. Retain the `features` list and aggregate `summary` even when a feature is
   selected. Show installed extension count, or unknown for `null`.
7. Always disclose `acceptance: NOT_ASSESSED` and `live_status: NOT_QUERIED`.
   Do not translate checked tasks into product completion, release readiness,
   kickoff authorization or live GitHub status.
