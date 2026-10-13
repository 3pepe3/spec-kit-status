#!/usr/bin/env bash
set -euo pipefail

# Read-only local artifacts. No task count establishes implementation acceptance.
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
    local code char escaped
    for ((code=1; code<32; code++)); do
        printf -v escaped '\\u%04x' "$code"
        printf -v char '%b' "$escaped"
        s="${s//$char/$escaped}"
    done
    printf '%s' "$s"
}
fail() { printf '{"error":"%s"}\n' "$(json_escape "$1")"; exit 1; }
find_repo_root() {
    local dir="$1"
    while :; do
        if [ -d "$dir/.specify" ]; then printf '%s' "$dir"; return 0; fi
        [ "$dir" = / ] && return 1
        dir="$(dirname "$dir")"
    done
}
selector="${SPECIFY_FEATURE:-}"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --feature) [ "$#" -ge 2 ] && [ -n "$2" ] || fail '--feature requires a value'; selector="$2"; shift 2 ;;
        --help|-h) printf 'Usage: status.sh [--feature NNN[-name]]\nRead-only JSON status; SPECIFY_INIT_DIR selects the project root.\n'; exit 0 ;;
        *) fail "Unknown argument: $1" ;;
    esac
done
if [ -n "${SPECIFY_INIT_DIR:-}" ]; then
    [ -d "$SPECIFY_INIT_DIR/.specify" ] || fail 'SPECIFY_INIT_DIR has no .specify directory'
    REPO_ROOT="$(cd "$SPECIFY_INIT_DIR" && pwd)"
else
    REPO_ROOT="$(find_repo_root "$PWD")" || fail 'Not a spec-kit project (no .specify directory)'
fi
SPECIFY_DIR="$REPO_ROOT/.specify"; SPECS_DIR="$REPO_ROOT/specs"
PROJECT_NAME="$(basename "$REPO_ROOT")"
HAS_GIT=false; CURRENT_BRANCH=""
if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --show-toplevel >/dev/null 2>&1; then
    HAS_GIT=true
    CURRENT_BRANCH="$(git -C "$REPO_ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
fi
if [ -z "$selector" ] && [[ "$CURRENT_BRANCH" =~ ^[0-9]{3}- ]]; then selector="$CURRENT_BRANCH"; fi
FEATURE_DIR=""
if [ -n "$selector" ]; then
    [[ "$selector" =~ ^[0-9]{3}(-[a-zA-Z0-9-]+)?$ ]] || fail 'Feature must be NNN or NNN-name'
    if [ -d "$SPECS_DIR/$selector" ]; then FEATURE_DIR="$SPECS_DIR/$selector"
    else
        matches=()
        for dir in "$SPECS_DIR/${selector:0:3}"-*/; do
            [ -d "$dir" ] && matches+=("${dir%/}")
        done
        [ "${#matches[@]}" -le 1 ] || fail "Ambiguous feature prefix: $selector; use the exact directory name"
        [ "${#matches[@]}" -eq 1 ] || fail "No specification directory for: $selector"
        FEATURE_DIR="${matches[0]}"
    fi
fi
# Shared skill folders alone do not identify Amp. Preserve its commands detection.
codex_skills=false
for manifest in "$REPO_ROOT"/.agents/skills/speckit-*/SKILL.md; do
    [ -f "$manifest" ] && codex_skills=true
done
declare -a AGENT_KEYS=("copilot" "claude" "gemini" "cursor-agent" "qwen" "opencode" "codex" "windsurf" "kilocode" "auggie" "codebuddy" "qodercli" "roo" "kiro-cli" "amp" "shai" "tabnine" "agy" "bob" "vibe" "kimi")
declare -a AGENT_NAMES=("GitHub Copilot" "Claude Code" "Gemini CLI" "Cursor" "Qwen Code" "opencode" "Codex CLI" "Windsurf" "Kilo Code" "Auggie CLI" "CodeBuddy" "Qoder CLI" "Roo Code" "Kiro CLI" "Amp" "SHAI" "Tabnine CLI" "Antigravity" "IBM Bob" "Mistral Vibe" "Kimi Code")
declare -a AGENT_FOLDERS=(".github" ".claude" ".gemini" ".cursor" ".qwen" ".opencode" ".codex" ".windsurf" ".kilocode" ".augment" ".codebuddy" ".qoder" ".roo" ".kiro" ".agents" ".shai" ".tabnine/agent" ".agent" ".bob" ".vibe" ".kimi")
declare -a AGENT_CMD_DIRS=("agents" "commands" "commands" "commands" "commands" "command" "prompts" "workflows" "workflows" "commands" "commands" "commands" "commands" "prompts" "commands" "commands" "commands" "workflows" "commands" "prompts" "skills")

detected_agents=""
for i in "${!AGENT_KEYS[@]}"; do
    folder="${AGENT_FOLDERS[$i]}"
    agent_dir="$REPO_ROOT/$folder"
    if [ "${AGENT_KEYS[$i]}" = amp ] && [ ! -d "$agent_dir/commands" ]; then continue; fi
    if [ -d "$agent_dir" ] || { [ "${AGENT_KEYS[$i]}" = codex ] && [ "$codex_skills" = true ]; }; then
        cmd_dir="$agent_dir/${AGENT_CMD_DIRS[$i]}"
        has_commands=false
        if [ -d "$cmd_dir" ] && [ -n "$(ls -A "$cmd_dir" 2>/dev/null)" ]; then
            has_commands=true
        fi
        if [ "${AGENT_KEYS[$i]}" = codex ] && [ "$codex_skills" = true ]; then
            has_commands=true
            folder=".agents/skills"
        fi
        entry="$(printf '{"key":"%s","name":"%s","folder":"%s","has_commands":%s}' \
            "$(json_escape "${AGENT_KEYS[$i]}")" \
            "$(json_escape "${AGENT_NAMES[$i]}")" \
            "$(json_escape "$folder/")" \
            "$has_commands")"
        if [ -z "$detected_agents" ]; then
            detected_agents="$entry"
        else
            detected_agents="$detected_agents,$entry"
        fi
    fi
done
AGENTS_JSON="[$detected_agents]"

# Both current .specify/scripts layouts are supported.
SCRIPT_TYPE=none
if [ -d "$SPECIFY_DIR/scripts/bash" ]; then SCRIPT_TYPE=sh; fi
if [ -d "$SPECIFY_DIR/scripts/powershell" ]; then
    if [ "$SCRIPT_TYPE" = sh ]; then SCRIPT_TYPE='sh + ps'; else SCRIPT_TYPE=ps; fi
fi

# Ignore fenced Markdown examples, including tilde and longer fences.
checkbox_counts() {
    awk '
    { line=$0; sub(/^[ \t]*/, "", line) }
    line ~ /^```/ || line ~ /^~~~/ {
        char=substr(line,1,1); n=0
        while(substr(line,n+1,1)==char) n++
        tail=substr(line,n+1)
        if(!fence) { fence=char; size=n }
        else if(char==fence && n>=size && tail ~ /^[ \t]*$/) { fence="" }
        next
    }
    !fence && line ~ /^-[ \t]+\[[ xX]\]([ \t]|$)/ {
        total++; if(line ~ /^-[ \t]+\[[xX]\]([ \t]|$)/) checked++
    }
    END { printf "%d %d\n", checked, total }' "$1"
}
feature_json() {
    local dir="$1" key flag name="" phase=no_feature hint='Select --feature or a numbered branch; no latest feature is inferred'
    local artifacts='' checked=0 total=0 contract_count=0 checklist_count=0 checklists_pass=true
    for key in spec plan tasks research data-model quickstart; do
        flag=false; [ -n "$dir" ] && [ -f "$dir/$key.md" ] && flag=true
        artifacts+="\"${key//-/_}\":$flag,"
    done
    if [ -n "$dir" ]; then
        name="$(basename "$dir")"
        if [ -f "$dir/tasks.md" ]; then
            read -r checked total < <(checkbox_counts "$dir/tasks.md")
            if [ "$total" -eq 0 ]; then phase=no_tasks; hint='No actionable tasks; roadmap pending'
            elif [ "$checked" -eq "$total" ]; then phase=tasks_checked; hint='Task bookkeeping checked; engineering acceptance is not assessed'
            else phase=implement; hint='Tasks available; verify authorization before implementation'; fi
        elif [ -f "$dir/plan.md" ]; then phase=tasks; hint='Plan exists; tasks are absent'
        elif [ -f "$dir/spec.md" ]; then phase=plan; hint='Specification exists; plan is absent'
        else phase=not_started; hint='Specification is absent'; fi
        for file in "$dir/contracts"/*; do [ -f "$file" ] && contract_count=$((contract_count+1)); done
        for file in "$dir/checklists"/*.md; do
            [ -f "$file" ] || continue
            checklist_count=$((checklist_count+1))
            read -r done_count all_count < <(checkbox_counts "$file")
            [ "$done_count" -eq "$all_count" ] || checklists_pass=false
        done
    fi
    local contracts=false checklists=false state=ROADMAP_PENDING
    [ "$contract_count" -gt 0 ] && contracts=true
    [ "$checklist_count" -gt 0 ] && checklists=true
    [ "$total" -gt 0 ] && state=TASKS_AVAILABLE
    printf '{"feature_name":"%s","artifacts":{%s"contracts":%s,"contract_count":%s,"checklists":%s,"checklist_count":%s,"checklists_all_pass":%s},"tasks":{"completed":%s,"total":%s},"task_state":"%s","phase":"%s","phase_hint":"%s","acceptance":"NOT_ASSESSED"}' \
        "$(json_escape "$name")" "$artifacts" "$contracts" "$contract_count" "$checklists" "$checklist_count" "$checklists_pass" "$checked" "$total" "$state" "$phase" "$hint"
}
features=''; feature_count=0; summary_checked=0; summary_total=0
for dir in "$SPECS_DIR"/[0-9][0-9][0-9]-*/; do
    [ -d "$dir" ] || continue
    [ -z "$features" ] || features+=,
    features+="$(feature_json "${dir%/}")"; feature_count=$((feature_count+1))
    if [ -f "$dir/tasks.md" ]; then
        read -r checked total < <(checkbox_counts "$dir/tasks.md")
        summary_checked=$((summary_checked+checked)); summary_total=$((summary_total+total))
    fi
done
summary_state=ROADMAP_PENDING; [ "$summary_total" -gt 0 ] && summary_state=TASKS_AVAILABLE
# jq is optional: do not invent an installed count when no JSON parser is available.
installed_count=null
if [ -f "$SPECIFY_DIR/extensions/.registry" ] && command -v jq >/dev/null 2>&1; then
    installed_count="$(jq -er '.extensions | objects | length' "$SPECIFY_DIR/extensions/.registry" 2>/dev/null)" || fail 'Invalid extension registry'
fi
active="$(feature_json "$FEATURE_DIR")"
printf '{"project_name":"%s","has_git":%s,"current_branch":"%s","script_type":"%s","agents":%s,"installed_extensions":%s,"feature_count":%s,"features":[%s],"summary":{"tasks":{"completed":%s,"total":%s},"task_state":"%s","acceptance":"NOT_ASSESSED"},"live_status":"NOT_QUERIED",%s}\n' \
    "$(json_escape "$PROJECT_NAME")" "$HAS_GIT" "$(json_escape "$CURRENT_BRANCH")" "$SCRIPT_TYPE" "$AGENTS_JSON" "$installed_count" "$feature_count" "$features" "$summary_checked" "$summary_total" "$summary_state" "${active:1:${#active}-2}"
