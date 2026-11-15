# my-plugin-marketplace

JaZahn's personal Claude Code plugin marketplace. Same layout as
[`harvard-huit/ats-plugin-marketplace`](https://github.com/harvard-huit/ats-plugin-marketplace):
one repo is both the marketplace and the plugins. Anything here is personal;
plugins that other people at ATS or HUIT would want belong in the ATS or
HUIT marketplaces instead.

| Plugin | What it does | Entry point |
|---|---|---|
| `trello` | Read and change your Trello boards, lists, and cards through Atlassian's hosted Trello MCP server, with an Atlassian login and no API key. Includes `card-first`: find or create the card for a work item before starting, keep it updated | `/trello:trello-setup`, then `/mcp`; `/trello:card-first` |

## Install

```
/plugin marketplace add jazahn/my-plugin-repository
/plugin install trello@my-plugin-marketplace
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
```

Validate before committing:

```
claude plugin validate .
claude plugin validate plugins/trello
claude plugin validate plugins/trello/skills
```

Bump the plugin's `version` on every change you publish; that field is what
tells installed copies an update exists.
