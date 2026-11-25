# my-plugin-marketplace

JaZahn's personal Claude Code plugin marketplace. Same layout as
[`harvard-huit/ats-plugin-marketplace`](https://github.com/harvard-huit/ats-plugin-marketplace):
one repo is both the marketplace and the plugins. Anything here is personal;
plugins that other people at ATS or HUIT would want belong in the ATS or
HUIT marketplaces instead.

| Plugin | What it does | Entry point |
|---|---|---|
| `trello` | Read and change your Trello boards, lists, and cards through Atlassian's hosted Trello MCP server, with an Atlassian login and no API key. Includes `card-first`: find or create the card for a work item before starting, keep it updated | `/trello:trello-setup`, then `/mcp`; `/trello:card-first` |
| `pr-assistant` | Automated review of every pull request in repos you enroll, run by `anthropics/claude-code-action` with this plugin's review rubric. One identical workflow file per repo; the auth mode (your subscription token, or the HUIT Bedrock proxy key for team repos) is picked by repo variables. Lists enrolled repos and rotates a credential across all of them in one pass | `/pr-assistant:install` in a repo; `/pr-assistant:rotate` |

## Install

```
/plugin marketplace add jazahn/my-plugin-repository
/plugin install trello@my-plugin-marketplace
/plugin install pr-assistant@my-plugin-marketplace
```

To work on it locally instead, add the checkout:

```
/plugin marketplace add ~/workshop/my-plugin-marketplace
```

## Updates

```
/plugin marketplace update my-plugin-marketplace
/plugin update trello@my-plugin-marketplace
/reload-plugins
```

Auto-update is off by default for non-Anthropic marketplaces; turn it on under
`/plugin` if you want the update nudge after session start.

## trello

Connects Claude to the Trello MCP server that Atlassian hosts at
`https://mcp.trello.com/v1`. The plugin is one MCP server declaration and a
setup skill. Install it, then type `/mcp`, pick `trello`, and choose
**Authenticate**: a browser tab opens on the Atlassian sign-in page, you sign
in with the Atlassian account that owns your boards, accept the consent page,
and the tab sends you back. There is no API key, token, client ID, or secret:
Atlassian's authorization server registers Claude Code as a client on the fly.

The server grants read **and write** scopes (boards, organizations, member
inbox, planner), so Claude can create, move, and edit cards once you approve a
call. Run `/trello:trello-setup` if anything is unclear or the server shows
as needing authentication; it checks for a hand-added duplicate, walks through
`/mcp`, and knows the common failures.

This is a different server from the Atlassian Rovo MCP server (`atlassian`,
for Jira and Confluence). Having one connected does not connect the other.

### card-first

A Trello counterpart to an "issue first" habit: before Claude starts on a
work item (a request that will change files or produce a deliverable, never a
question), it looks for the matching card on your board and asks one question
at most: link an existing card, create a drafted one, or skip. It works in any
directory, git or not. When the work lands or the item wraps up, it offers one
batched update to the card (a short comment, and a move to done when the item
is finished). Nothing is written to Trello without your yes.

It is configured per project in `CLAUDE.local.md` (per-machine, never
committed):

```
card-first: on                                   # or off; the skill asks once when unset
card-first-board: https://trello.com/b/<shortLink>/<slug>   # set automatically when you have one board
card-first-list: Do it                           # optional: the list new cards go on
```

A `SessionStart` hook reads that file and reminds Claude to run the check when
a work item starts; with `card-first: off` it stays silent. Invoke it by hand
with `/trello:card-first`.

## pr-assistant

Turns Claude into a reviewer for every pull request in the repos you choose.
A Claude Code plugin cannot see GitHub events, so the trigger is a GitHub
Actions workflow in each repo running `anthropics/claude-code-action@v1`;
the plugin carries the review rubric the action runs (`/pr-assistant:review`)
and the tooling around it. The workflow file is identical in every enrolled
repo. Which credential it runs on is chosen by repo variables, so switching
modes later touches no file:

| Mode | Credential | For |
|---|---|---|
| `personal` | secret `CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token` (one year, your subscription) | repos you own |
| `team` | secret `PR_ASSISTANT_API_KEY`, an Apigee key for the HUIT Bedrock proxy, plus `PR_ASSISTANT_PROXY_URL` and `PR_ASSISTANT_MODEL` | team repos; billed to the API product, not a person |

Nothing here needs an org admin: no org secrets, no GitHub App install on
the org, no Console setup. Secrets are set by you at your terminal; the
skills never see the values.

- `/pr-assistant:install` in a checkout: copies the workflow to
  `.github/workflows/pr-assistant.yml`, prints the `gh secret set` command
  for you to run, sets `PR_ASSISTANT_MODE` and `PR_ASSISTANT_MINTED` (and the
  team variables), and offers a branch and PR. The PR is the first test.
- `/pr-assistant:rotate`: finds every enrolled repo on github.com and
  github.huit.harvard.edu by the workflow file, shows mode and credential
  age, and with `personal` or `team` prints one loop that rotates that
  secret in all of them. A `SessionStart` hook nudges once when a
  credential passes eleven months, from a per-machine cache in
  `~/.claude/pr-assistant-rotation.md`.
- `/pr-assistant:review`: the rubric (correctness, security, untested
  behavior changes, scope; small fixes as `suggestion` blocks; out-of-scope
  work as one follow-up paragraph, never a new PR). It delegates the diff
  review and the inline posting to the official `code-review` plugin, which
  the workflow installs alongside this one.

Version 0.1 posts review comments only; it never pushes. Not meant to be a
required check.

## Layout

```
.claude-plugin/marketplace.json          the marketplace
plugins/trello/
  .claude-plugin/plugin.json             manifest
  .mcp.json                              trello (hosted, OAuth with dynamic client registration)
  hooks/hooks.json                       SessionStart nudge for card-first (reads CLAUDE.local.md)
  scripts/card-first-nudge.sh            the hook script; prints nothing when card-first is off
  skills/trello-setup/SKILL.md           the /mcp walkthrough and troubleshooting
  skills/card-first/SKILL.md             find or create the card for a work item, keep it updated
plugins/pr-assistant/
  .claude-plugin/plugin.json             manifest
  hooks/hooks.json                       SessionStart nudge when a credential is due for rotation
  scripts/rotation-nudge.sh              the hook script; reads ~/.claude/pr-assistant-rotation.md
  templates/pr-assistant.yml             the workflow file install copies into repos, unchanged
  skills/review/SKILL.md                 the rubric the action runs; delegates to code-review
  skills/install/SKILL.md                enroll a repo: workflow, secret (by you), variables, PR
  skills/rotate/SKILL.md                 list enrolled repos; rotate one mode's secret everywhere
```

Validate before committing:

```
claude plugin validate .
claude plugin validate plugins/trello
claude plugin validate plugins/trello/skills
claude plugin validate plugins/pr-assistant
claude plugin validate plugins/pr-assistant/skills
```

Bump the plugin's `version` on every change you publish; that field is what
tells installed copies an update exists.
