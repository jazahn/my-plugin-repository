---
name: rotate
description: List every repo enrolled in pr-assistant review with its auth mode and credential age, and rotate one mode's credential across all of those repos in one pass. Use when the user asks "which repos have the PR assistant", "when does the review token expire", "rotate the PR assistant token", "rotate the team key", or invokes /pr-assistant:rotate, and when the plugin's SessionStart nudge says a credential is due. With no argument this only lists; with `personal` or `team` it rotates that mode.
---

# List and rotate

The enrollment record is in each repo: the workflow file
`.github/workflows/pr-assistant.yml` and the variables `PR_ASSISTANT_MODE`
and `PR_ASSISTANT_MINTED`. There is no central list to keep in sync; this
skill rebuilds it from the repos each time. No secret value ever passes
through this session: the user runs the `gh secret set` loop at their own
terminal.

## Step 1: find enrolled repos

For each host the user is logged in to (`gh auth status`): github.com as
is, github.huit.harvard.edu with `GH_HOST=github.huit.harvard.edu`.

1. Candidate repos. The user's own, plus any org the user names:

   ```sh
   gh repo list <owner> --limit 200 --json nameWithOwner --jq '.[].nameWithOwner'
   ```

   On github.com, `gh search code 'filename:pr-assistant.yml path:.github/workflows' --owner <owner> --json repository --jq '.[].repository.nameWithOwner'`
   is a cheaper first pass when it works; code search lags and is not on
   every GHES, so the listing below is the one that counts.

2. Enrolled = the workflow file exists:

   ```sh
   gh api repos/<owner>/<repo>/contents/.github/workflows/pr-assistant.yml --silent && echo enrolled
   ```

   A 404 means not enrolled. Run these in one shell loop, not one call
   per turn.

3. For each enrolled repo read the record:

   ```sh
   gh variable get PR_ASSISTANT_MODE -R owner/repo
   gh variable get PR_ASSISTANT_MINTED -R owner/repo
   ```

   Missing variables mean a hand-made or partial enrollment; show them as
   `?` and say so.

Print one table: repo, host, mode, minted, age in months, and `due` when
the age is eleven months or more. With no argument, stop here.

## Step 2: rotate one mode

The argument is `personal` or `team`. Only repos in that mode are touched.

1. Have the user mint the new credential: `claude setup-token` for
   personal; a new Apigee key for the Bedrock proxy for team.
2. Print one loop for the user to run at their terminal, with the actual
   repo list filled in, so the value is entered once and never echoed:

   ```sh
   read -rs -p 'New value: ' V; echo
   for r in owner/a owner/b; do printf '%s' "$V" | gh secret set CLAUDE_CODE_OAUTH_TOKEN -R "$r"; done
   unset V
   ```

   Use `PR_ASSISTANT_API_KEY` for team. Print a separate loop per host
   with the `GH_HOST=` prefix on the GHES one. Wait for the user to say it
   ran.
3. Update the mint date everywhere in that mode:

   ```sh
   gh variable set PR_ASSISTANT_MINTED --body YYYY-MM-DD -R owner/repo
   ```

4. Refresh `~/.claude/.pr-assistant-rotation`: set that mode's line to
   the new mint date plus eleven months.
5. Re-run step 1 and show the table so the result is visible.

## Rules

- Never run `gh secret set`, never ask for or accept a credential value in
  chat, never read a `.credentials.env` or similar file.
- Read-only until the user confirms the loop ran; the only writes this
  skill makes itself are `gh variable set` and the cache file.
- Repos in the other mode are listed but not changed.
- A repo that fails (no admin, archived) is reported by name, and the
  rest proceed.
