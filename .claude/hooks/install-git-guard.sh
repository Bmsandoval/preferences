#!/usr/bin/env bash
# Install the git-destruction guard's hook registration into ~/.claude/settings.json.
#
# Why an installer rather than a tracked settings.json: settings.json also holds
# machine/account state (autoMode environment, theme, effort level) that does not
# belong in a public dotfiles repo, and Claude Code's user settings have no
# include/extends mechanism — the hooks block must physically live in that file.
# So the REGISTRATION is tracked here as settings.hooks.json and merged in.
#
# Idempotent: re-running is a no-op once the hook is registered. Existing hooks
# and every other settings key are preserved. Run after a machine rebuild:
#
#     bash ~/.claude/hooks/install-git-guard.sh
#
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAG="$DIR/settings.hooks.json"
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
GUARD="$DIR/block-destructive-git.sh"

command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }
[ -f "$FRAG" ]  || { echo "error: missing fragment $FRAG" >&2; exit 1; }
[ -f "$GUARD" ] || { echo "error: missing guard script $GUARD" >&2; exit 1; }
chmod +x "$GUARD"

[ -f "$SETTINGS" ] || { mkdir -p "$(dirname "$SETTINGS")"; echo '{}' > "$SETTINGS"; }
jq -e . "$SETTINGS" >/dev/null || { echo "error: $SETTINGS is not valid JSON — fix it first" >&2; exit 1; }

# Append only the entries whose command is not already registered for that event,
# so other hooks (and a previous install) survive untouched.
merged="$(jq --slurpfile f "$FRAG" '
  ($f[0].hooks) as $fh
  | reduce ($fh | keys_unsorted[]) as $ev (.;
      ( [ (.hooks[$ev] // [])[] | (.hooks // [])[] | .command ] ) as $have
      | .hooks[$ev] = ((.hooks[$ev] // []) + (
          $fh[$ev] | map( select( [ (.hooks // [])[] | .command ] | all( . as $c | $have | index($c) | not ) ) )
        ))
    )
' "$SETTINGS")"

printf '%s\n' "$merged" | jq -e . >/dev/null || { echo "error: merge produced invalid JSON; settings untouched" >&2; exit 1; }

if [ "$(printf '%s' "$merged" | jq -S -c .)" = "$(jq -S -c . "$SETTINGS")" ]; then
  echo "git guard already registered in $SETTINGS — nothing to do"
  exit 0
fi

cp "$SETTINGS" "$SETTINGS.bak"
printf '%s\n' "$merged" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
echo "registered git guard in $SETTINGS (backup at $SETTINGS.bak)"
echo "note: open a new session, or run /hooks, for Claude Code to reload settings"
