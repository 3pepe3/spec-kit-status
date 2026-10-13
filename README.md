# Spec Kit Status

A read-only Spec Kit extension showing local artifacts and task bookkeeping.
It does not query GitHub, grant implementation authorization, or assess acceptance.

## Installation

```bash
specify extension add status
```

The published v1.0.0 archive is also available:

```bash
specify extension add status --from https://github.com/KhawarHabibKhan/spec-kit-status/archive/refs/tags/v1.0.0.zip
```

The changes described below are unreleased; the published archive may still use
legacy layout assumptions.

## Usage

Use `/speckit.status.show` (alias `/speckit.status`), optionally followed by a
feature selector such as `003` or `003-media`. The command instructions pass the
selector to the script. For Codex installations that expose extension commands
as skills, use `$speckit-status-show` (alias `$speckit-status`) with the same
optional selector. To invoke scripts directly from this extension checkout:

```bash
bash scripts/bash/status.sh --feature 003
```

```powershell
./scripts/powershell/status.ps1 -Feature 003
```

Scripts inspect the nearest ancestor containing `.specify/`, or the directory
selected by `SPECIFY_INIT_DIR`. Select a feature in this order:

1. Explicit `--feature` / `-Feature` argument.
2. `SPECIFY_FEATURE` environment variable.
3. Current Git branch, only when it starts with a three-digit feature prefix.

An exact `specs/NNN-name/` directory wins; otherwise the three-digit prefix must
match one directory. Invalid, missing or ambiguous selections return a JSON
error and nonzero exit. Without a selector, main/master, detached HEAD and
non-Git projects show the all-feature summary and `phase: no_feature`. There is
no latest-feature fallback. Bash `--help` / `-h` prints usage instead of JSON.

## Output and scope

Normal output is a single JSON document, including errors detected by the script.
It includes project/branch information, agent discovery, `script_type`, selected
feature artifacts/tasks/phase, `features` for every numbered directory and an
aggregate `summary`. Empty task files report `no_tasks` / `ROADMAP_PENDING`.
All checked tasks report `tasks_checked`, never acceptance: `acceptance` is
always `NOT_ASSESSED`, and `live_status` is always `NOT_QUERIED`.

Task and checklist counters recognize `- [ ]`, `- [x]` and `- [X]` followed by
whitespace or end of line. Backtick and tilde fenced examples, including longer
fences, are excluded. These are Markdown checkbox counts, not validation of task
IDs, prerequisites, acceptance evidence or complete Markdown semantics.

Current layouts `.specify/scripts/bash/`, `.specify/scripts/powershell/` and
Codex `.agents/skills/speckit-*/SKILL.md` are recognized. Legacy Codex
`.codex/prompts/` commands remain supported. Shared `.agents/skills/` alone does
not identify Amp; Amp requires `.agents/commands/`.

Installed extensions are counted from `.specify/extensions/.registry`'s
`extensions` object. Bash needs optional `jq` to read that registry; without it,
or without a registry, the count is `null` (unknown). Malformed registries fail
when a parser is available. PowerShell uses its built-in JSON parser.

## Requirements and verification

Spec Kit >= 0.1.0; Bash >= 4.2 with awk, or PowerShell >= 5.1. Git is optional.
No Python dependency is required for the status scripts. Fixture tests require
Python 3 and Git:

```bash
python3 -m unittest discover -s tests -v
bash -n scripts/bash/status.sh
```

The same fixture contract runs against PowerShell when `pwsh` is installed;
otherwise those tests explicitly skip. PowerShell source has been updated for
parity, but runtime parity is unverified in environments without that runtime.
