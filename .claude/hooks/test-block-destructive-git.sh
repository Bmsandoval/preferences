#!/usr/bin/env bash
# Regression suite for the destructive-git PreToolUse hook.
H=/Users/bryansandoval/.claude/hooks/block-destructive-git.sh
fails=0

t() {
  want="$1"; cmd="$2"
  out=$(python3 -c "import json,sys;print(json.dumps({'tool_name':'Bash','tool_input':{'command':sys.argv[1]}}))" "$cmd" | bash "$H")
  # DENY only when the hook actually emits a deny decision; the override path
  # emits a systemMessage and still allows, so "any output" is not the test.
  dec=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)
  got=$([ "$dec" = "deny" ] && echo DENY || echo ALLOW)
  if [ "$got" = "$want" ]; then
    printf 'ok    %-5s | %s\n' "$got" "$cmd"
  else
    printf 'BAD   got %-5s want %-5s | %s\n' "$got" "$want" "$cmd"
    fails=$((fails+1))
  fi
}

echo "--- must be DENIED ---"
t DENY 'git reset --hard origin/develop'
t DENY 'git clean -fd'
t DENY 'git clean --force'
t DENY 'git push --force origin develop'
t DENY 'git push -f'
t DENY 'git push --force-with-lease origin develop'
t DENY 'git branch -D feature/x'
t DENY 'git stash drop'
t DENY 'git stash clear'
t DENY 'git checkout -- .'
t DENY 'git checkout -- src/main.go'
t DENY 'git restore src/main.go'
t DENY 'cd /tmp && git reset --hard HEAD~3'
t DENY 'git -C /some/repo reset --hard HEAD'
t DENY 'git worktree remove /tmp/scratch --force'
t DENY 'git worktree remove -f /tmp/scratch'

echo "--- must be ALLOWED (regressions) ---"
t ALLOW 'git checkout -q my-branch && echo "--- header ---"'
t ALLOW 'git checkout -b feat/new develop'
t ALLOW 'git checkout develop'
t ALLOW 'git restore --staged file.txt'
t ALLOW 'git status --short'
t ALLOW 'git push origin develop'
t ALLOW 'git reset --soft HEAD~1'
t ALLOW 'git reset HEAD file.txt'
t ALLOW 'git branch -d merged-branch'
t ALLOW 'git branch --show-current'
t ALLOW 'git stash list'
t ALLOW 'git stash push -u'
t ALLOW 'git log --oneline -- src/'
t ALLOW 'git diff -- src/main.go'
t ALLOW 'echo "--- done ---"'
t ALLOW 'ls -la'
t ALLOW 'make clean -f Makefile.ci'
t ALLOW 'git worktree remove /tmp/scratch'
t ALLOW 'git worktree add /tmp/wt -b feat/x develop'
t ALLOW 'git worktree list'
t ALLOW 'git switch -C develop origin/develop'

echo "--- override escape ---"
t ALLOW 'GIT_GUARD_OVERRIDE=user-approved-cleanup git branch -D tmp/scratch'
t ALLOW 'GIT_GUARD_OVERRIDE=stale-ref git reset --hard origin/develop'
t ALLOW 'GIT_GUARD_OVERRIDE=redundant-wip git stash drop stash@{0}'
t DENY  'GIT_GUARD_OVERRIDE= git reset --hard origin/develop'
t DENY  'git reset --hard origin/develop # GIT_GUARD_OVERRIDE'

echo
[ "$fails" -eq 0 ] && echo "ALL PASS" || echo "$fails FAILURE(S)"
exit "$fails"
