# Spec Kit Status

A Spec Kit extension that shows project status and SDD workflow progress.

## What it does

Shows a unified overview of your Spec Kit project:

- **Project info** — name, detected AI agent(s), script type
- **Current feature** — from an explicit directory or the current feature pointer
- **SDD artifacts** — which files exist (spec.md, plan.md, tasks.md, etc.)
- **Task progress** — completed/total with percentage from tasks.md
- **Workflow phase** — which SDD step you're on (Plan → Tasks → Implement → Complete)
- **Extensions** — how many are installed

## Installation

```bash
specify extension add status
```

Or install from GitHub:

```bash
specify extension add status --from https://github.com/KhawarHabibKhan/spec-kit-status/archive/refs/tags/v1.0.0.zip
```

## Usage

```
/speckit.status.show
```

Or using the alias:

```
/speckit.status
```

## Requirements

- Spec Kit >= 0.1.0

## Bash selection and task counting

The Bash probe recognizes current Codex skills in `.agents/skills/`. Feature
selection uses SPECIFY_FEATURE_DIRECTORY, then `.specify/feature.json`, matching
Spec Kit 1.1.3. SPECIFY_FEATURE labels a selection; it cannot select a directory
on its own and must agree with the selected directory name. Git branches never
select or guess a feature. Invalid directories fail explicitly. Pointer reads do
not modify the project. Task counting ignores fenced Markdown examples and accepts
a final line without a newline. Checked counts describe task bookkeeping, not
application acceptance. Run `python3 -m unittest discover -s tests -v` for Bash
regressions. Python 3 is needed for current JSON feature pointers; PowerShell has
not yet been brought to parity with these changes.
