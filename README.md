# Spec Kit Status

A Spec Kit extension that shows project status and SDD workflow progress.

## What it does

Shows a unified overview of your Spec Kit project:

- **Project info** — name, detected AI agent(s), script type
- **Current feature** — from git branch, SPECIFY_FEATURE env var, or specs/ scan
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
specify extension add --from https://github.com/KhawarHabibKhan/spec-kit-status/archive/refs/tags/v1.0.0.zip
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

## Maintained native-layout compatibility

The 3pepe3 fork v1.0.1 verifies the Bash entrypoint against Spec Kit1.2.1
and Codex skills mode. It reads native integration state, `.specify/feature.json`
and environment feature selection, the `.registry` extension registry, and
only numbered feature directories. Shared contracts are not features.
Fenced example checkboxes are excluded. Bash requires Python3 and emits JSON;
`--json` is accepted for compatibility. It is read-only and reports errors with
a nonzero exit. Original PowerShell scripts remain, but native1.2 compatibility
has not been verified on Windows. Task counts never imply acceptance.
