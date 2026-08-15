#!/usr/bin/env bash
# PreToolUse(Bash) guard: refuse git commands that destroy uncommitted or unpushed work.
# See the "Git workflow policy" section of ~/.claude/CLAUDE.md.
# Emits a PreToolUse deny decision; anything else falls through silently (exit 0).
#
# Matching notes: patterns are space-delimited regexes, not globs. An earlier glob
# version matched the "-- " inside ordinary text like "--- header ---" and blocked
# plain branch switches. [^&|;]* keeps a match inside a single shell segment, so a
# later command in a chain cannot pull an earlier verb into range.

cmd="$(jq -r '.tool_input.command // empty')"
[ -n "$cmd" ] || exit 0

policy="Blocked by the global git workflow policy (~/.claude/CLAUDE.md). Never discard work that may be uncommitted or unpushed. Check 'git status' and 'git log origin/<branch>..HEAD' and ask the user before any recovery. If the user has explicitly approved THIS operation, re-run it prefixed with GIT_GUARD_OVERRIDE=<reason> — the override is logged and shown to them, so never add it on your own initiative."

# --- Escape hatch -----------------------------------------------------------
# GIT_GUARD_OVERRIDE=<reason> as a command prefix lets one destructive command
# through. This is NOT a security boundary: anything with shell access could
# type the prefix, or reach the same ref via update-ref. Its job is to make a
# bypass LOUD and ATTRIBUTABLE instead of silent — every use is appended to the
# audit log and surfaced to the user in the UI. Only legitimate after the user
# has approved that specific operation in conversation.
AUDIT="$HOME/.claude/git-guard-overrides.log"
override_reason="$(printf '%s' "$cmd" | sed -n 's/.*GIT_GUARD_OVERRIDE=\([^ ;|&]*\).*/\1/p')"
if [ -n "$override_reason" ]; then
  printf '%s\treason=%s\tcmd=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$override_reason" "$cmd" >> "$AUDIT" 2>/dev/null
  jq -n --arg r "$override_reason" --arg c "$cmd" \
    '{systemMessage: ("git guard OVERRIDDEN (reason: " + $r + ") for: " + $c + "  — logged to ~/.claude/git-guard-overrides.log")}'
  exit 0
fi

deny() {
  jq -n --arg r "$1 $policy" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

match() { printf '%s' "$cmd" | grep -Eq "$1"; }

match 'git[[:space:]]+([^&|;]*[[:space:]])?reset[^&|;]*--hard' &&
  deny "git reset --hard destroys uncommitted changes and, against a remote ref, unpushed commits."

match 'git[[:space:]]+([^&|;]*[[:space:]])?clean[^&|;]*([[:space:]]-[a-zA-Z]*f|--force)' &&
  deny "git clean -f deletes untracked files permanently."

match 'git[[:space:]]+([^&|;]*[[:space:]])?push[^&|;]*(--force|[[:space:]]-f([[:space:]]|$))' &&
  deny "git push --force can overwrite commits on the remote."

match 'git[[:space:]]+([^&|;]*[[:space:]])?branch[^&|;]*([[:space:]]-[a-zA-Z]*D|--delete[^&|;]*--force)' &&
  deny "git branch -D deletes a branch even if it holds unmerged commits."

match 'git[[:space:]]+([^&|;]*[[:space:]])?stash[[:space:]]+(drop|clear)' &&
  deny "Dropping or clearing stashes permanently discards stashed work."

# Plain "worktree remove" already refuses a dirty tree; --force is the form that
# throws the work away, and a parallel agent may be mid-edit in there.
match 'git[[:space:]]+([^&|;]*[[:space:]])?worktree[^&|;]*remove[^&|;]*(--force|[[:space:]]-f([[:space:]]|$))' &&
  deny "git worktree remove --force discards whatever that worktree was holding, including another agent's in-progress edits."

# "checkout -- <path>" discards working-tree changes. Require a space on both sides
# of the -- so "---" in surrounding prose cannot trigger it.
match 'git[[:space:]]+([^&|;]*[[:space:]])?checkout[^&|;]*[[:space:]]--[[:space:]]' &&
  deny "git checkout -- <path> discards uncommitted changes in the working tree."

# git restore discards working-tree changes, except --staged (which only unstages).
if match 'git[[:space:]]+([^&|;]*[[:space:]])?restore([[:space:]]|$)' && ! match 'restore[^&|;]*--staged'; then
  deny "git restore discards uncommitted changes in the working tree."
fi

exit 0
