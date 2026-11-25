---
name: install
description: Enroll the current repository in automated PR review by the pr-assistant plugin. Writes the one workflow file, has you set the repo secret yourself, sets the repo variables that pick the auth mode (personal subscription token or team HUIT Bedrock proxy key), records the rotation date, and offers a branch and pull request. Use when the user says "install the PR assistant here", "enroll this repo", "set up PR review for this repo", "add the review workflow", or invokes /pr-assistant:install. Not for rotating or listing credentials; that is /pr-assistant:rotate.
---

# Enroll a repo

One workflow file, one secret, a few variables. The file is identical in
every enrolled repo; the variables carry the mode. Nothing is pushed to
the default branch directly, and no secret value ever passes through this
session: the user sets secrets at their own terminal.

## Step 0: where are we

- Repo root: `git rev-parse --show-toplevel`. Not a git checkout, or no
  `origin` remote: say so and stop.
- Host and `owner/repo` from `git remote get-url origin`. For
  `github.huit.harvard.edu` every `gh` call below gets
  `GH_HOST=github.huit.harvard.edu`; for `github.com` nothing extra. Any
  other host: not supported, say so and stop.
- `gh auth status` must show a login for that host. If not, point at
  `/huit-github:github-setup` and stop.
- Already enrolled (`.github/workflows/pr-assistant.yml` exists)? Say so,
  show the current variables (`gh variable list -R owner/repo`), and stop
  unless the user asks to re-install, in which case continue and overwrite.
- Setting secrets and variables needs admin on the repo. If step 3 fails
  with a permissions error, say that is the cause.

In a repo where the personal `issue-first` skill or `card-first` applies,
their check runs as usual for this work item; this skill adds nothing to
that question.

## Step 1: mode

Ask once (AskUserQuestion when interactive):

> Which credential should the review run on?
> - **personal**: your Claude subscription, through a one-year OAuth token
>   from `claude setup-token`. For repos you own. Tied to your subscription.
> - **team**: the HUIT Bedrock proxy, through an Apigee API key. Billed to
>   the team's API product, not to a person. For team repos.

In a non-interactive session with no mode given as an argument, stop and
say the mode is needed. The argument may be `personal` or `team`.

Team mode has two defaults the user may override in the same question or
as arguments:

- proxy URL: `https://go.apis.huit.harvard.edu/ais-bedrock-llm/v2`
- model: `us.anthropic.claude-fable-5` (a `us.`-prefixed Bedrock inference
  profile id with no `-0` suffix; the proxy rejects other forms)

## Step 2: the workflow file

Copy the template verbatim; do not edit it per repo:

```sh
mkdir -p .github/workflows
cp "${CLAUDE_PLUGIN_ROOT}/templates/pr-assistant.yml" .github/workflows/pr-assistant.yml
```

If `CLAUDE_PLUGIN_ROOT` is not set in this session, the plugin root is the
directory two levels above this skill's own directory.

## Step 3: the secret, by the user

Print the exact commands and wait for the user to say they ran them. Never
run `gh secret set` yourself, never ask for the value, never accept it in
chat. `gh secret set` prompts for the value when run at a terminal and
nothing is echoed.

Personal:

```sh
claude setup-token          # browser approval; prints a one-year token, copy it
gh secret set CLAUDE_CODE_OAUTH_TOKEN -R owner/repo
```

Team:

```sh
gh secret set PR_ASSISTANT_API_KEY -R owner/repo    # paste the Apigee key for the Bedrock proxy
```

Prefix both with `GH_HOST=github.huit.harvard.edu` on that host. Confirm
afterwards with `gh secret list -R owner/repo` (names only).

## Step 4: the variables

Today's date as `YYYY-MM-DD` is the mint date. If the user says the
credential was created earlier (a token reused from another repo), use
that date instead.

```sh
gh variable set PR_ASSISTANT_MODE --body personal -R owner/repo      # or team
gh variable set PR_ASSISTANT_MINTED --body YYYY-MM-DD -R owner/repo
```

Team mode also:

```sh
gh variable set PR_ASSISTANT_PROXY_URL --body https://go.apis.huit.harvard.edu/ais-bedrock-llm/v2 -R owner/repo
gh variable set PR_ASSISTANT_MODEL --body us.anthropic.claude-fable-5 -R owner/repo
```

These are the enrollment record. `/pr-assistant:rotate` reads them back.

## Step 5: the rotation cache

Append or replace the line for this mode in
`~/.claude/pr-assistant-rotation.md` with the rotate-by date, the mint
date plus eleven months (a one-year token minted 2026-11-25 gets
`personal: 2027-10-25`). The plugin's SessionStart hook reads this file
and nudges once when a date has passed. It is a per-machine cache; the
repo variables are the truth. Keep the earliest date when several repos
share a mode.

## Step 6: commit and PR

Never commit to the default branch. On a new branch (`pr-assistant/enroll`
unless the repo has a convention), commit the workflow file with a message
such as `Enroll in automated PR review (pr-assistant)`, referencing the
issue when `issue-first` found or created one. Then offer `gh pr create`.
The PR itself is the first test: when it opens, the workflow runs on it
and the review should appear within a few minutes. If it does not, open
the Actions log for the run; the first lines of the action show which
auth path it took and whether the two plugins installed.

Report at the end: the file written, the variables set, the secret name
the user set, the branch, and the PR URL if one was opened.
