# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

JaZahn's **personal** Claude Code plugin marketplace, started 2026-11-05 as a
copy of the shape of `~/workshop/ats-plugin-marketplace`
(`harvard-huit/ats-plugin-marketplace`, the ATS team marketplace). That repo's
`CLAUDE.md` holds the long design history (GitHub auth paths, Apigee, AWS,
Slack rejection); do not copy it here. This file keeps only what applies to
this repo. When a plugin here turns out to be useful to the team, move it to
the ATS marketplace and leave a pointer in the README.

Marketplace name: `my-plugin-marketplace` (also the checkout directory).
Remote: `https://github.com/jazahn/my-plugin-repository` (public, empty as of
2026-11-05). The repo name and the marketplace name differ; the install
command uses the repo (`/plugin marketplace add jazahn/my-plugin-repository`)
and the plugin install uses the marketplace name
(`trello@my-plugin-marketplace`). The marketplace name is baked into every
local registration, so decide the final name before anyone else adds it.

One plugin so far: `trello`.

Status (2026-11-15): all three `claude plugin validate` targets pass;
`trello` 0.2.0 adds the `card-first` skill and its `SessionStart` hook (#2)
and is installed at user scope from this checkout on JaZahn's Mac. The
2026-11-05 scaffold is committed and pushed (758cd84) and a claude.ai-synced
copy of 0.1.0 exists; the 0.2.0 changes are uncommitted. Tracking: issue #1
(the plugin and its verification gate), #2 (`card-first`), #3 (repo rename).

## Commands

Validate before every commit. Each call checks one thing (marketplace
manifest, plugin manifest, skill frontmatter), so run all three per plugin:

```sh
claude plugin validate .
claude plugin validate plugins/trello
claude plugin validate plugins/trello/skills
```

Test from the local checkout, not from GitHub:

```sh
claude plugin marketplace add ~/workshop/my-plugin-marketplace
claude plugin install trello@my-plugin-marketplace
claude plugin list --json          # installPath shows the cached copy
```

The install is a **copy** into `~/.claude/plugins/cache/my-plugin-marketplace/<name>/<version>/`,
not a link. After editing anything, `claude plugin uninstall trello@my-plugin-marketplace`
then install again, or bump the version. `.mcp.json` is read at install
time; skills at session start; a new MCP server only connects in a session
started after the install.

Bump `version` in the plugin's `plugin.json` on every published change. It is
the only update signal installed copies see.

## Layout and conventions

```
.claude-plugin/marketplace.json     name, owner, plugins[] with "source": "./plugins/<name>"
plugins/<name>/
  .claude-plugin/plugin.json        name, displayName, version, description, author, repository, license, keywords
  .mcp.json                         MCP servers, at the plugin root (not inside .claude-plugin/)
  hooks/hooks.json                  hooks, wrapped in a top-level "hooks" key
  scripts/*.sh                      hook helpers, run as "${CLAUDE_PLUGIN_ROOT}"/scripts/<name>.sh
  skills/<skill>/SKILL.md           frontmatter name = invocation name, /<plugin>:<skill>
CLAUDE.local.md                     per-machine, excluded via .git/info/exclude (issue-first and card-first settings)
```

- Inside a plugin only `plugin.json` lives in `.claude-plugin/`; everything
  else is at the plugin root.
- Never put a `.mcp.json` at the repo root. Claude Code reads it as a
  *project* MCP config in every session opened here.
- No top-level `bin/` in any plugin (claude.ai plugin sync skips such
  plugins). Helpers go in `scripts/`, referenced as
  `"${CLAUDE_PLUGIN_ROOT}/scripts/..."` (quoted) from `.mcp.json`, hooks, or
  skills.
- Plugin-root `settings.json` cannot ship permissions; a setup skill may
  offer an allowlist for the user's own `~/.claude/settings.json` instead.
- Never commit a token or a person's login. A local-path install copies
  gitignored files too, so nothing sensitive may sit in this tree at all.

## The OAuth MCP plugin shape

`trello` is the thinnest plugin shape, copied from `huit-maestro` and
`huit-servicenow-dev` in the ATS marketplace: one `http` server in
`.mcp.json` plus a `<name>-setup` skill. No `headersHelper`, no wrapper
script, no auth hook (the `card-first` hook below is a process nudge, not
part of the auth path). It works only when the remote server implements the MCP
authorization spec end to end: `401` with `WWW-Authenticate:
Bearer resource_metadata=...`, an RFC 9728 protected-resource document naming
the authorization server, and that server advertising a
`registration_endpoint` (dynamic client registration) and S256 PKCE. Check
all three with curl before adding a server in this shape; a server without
DCR (GitHub's, for example) needs a different design.

Facts that follow from the shape (verified on Claude Code 2.1.267):

- Plugin-shipped servers appear in a session as `plugin:<plugin>:<server>`
  and their tools as `mcp__plugin_<plugin>_<server>__<tool>`, so Trello's
  are `mcp__plugin_trello_trello__*`. A settings allowlist uses that form,
  not `mcp__trello__*`.
- The only way to authorize a plugin-shipped server is the in-session
  `/mcp` menu. `claude mcp list`, `claude mcp get`, and `claude mcp login`
  do not see plugin servers. Nothing in `.mcp.json` pre-authorizes.
- A hand-added `claude mcp add <same name>` entry does not collide by name
  with the plugin's server; it duplicates every tool. Setup skills check for
  it with `claude mcp get <name>` and offer removal.
- The setup skill does not list the server's tools; each tool carries its own
  description and a copy here would drift.

## trello plugin

Endpoint `https://mcp.trello.com/v1`, Atlassian-hosted. Probed live
2026-11-05, do not re-derive:

- Unauthenticated `initialize` returns `401 {"error":"invalid_token"}` with
  `WWW-Authenticate: Bearer resource_metadata="https://mcp.trello.com/.well-known/oauth-protected-resource/v1"`.
  The path-less `/.well-known/oauth-protected-resource` is not served
  (Atlassian edge error page); only the `/v1`-suffixed form exists.
- That document names one authorization server,
  `https://auth.atlassian.com/VCeDsk8ZHncYF1g234fKtc4lNipbBhu3`, bearer
  method `header`, and these scopes: `offline_access`, `read:me`,
  `read:account`, `read:board:trello`, `write:board:trello`,
  `read:organization:trello`, `write:organization:trello`,
  `read:member:trello`, `read:member.inbox:trello`,
  `write:member.inbox:trello`, `read:member.planner:trello`,
  `write:member.planner:trello`. **Write scopes are included**; unlike the
  Maestro and ServiceNow plugins this one is not read-only, and the skill
  says so.
- The authorization server's metadata (both RFC 8414 path forms answer)
  advertises `authorize` and `/oauth/token` on `auth.atlassian.com`, a
  `registration_endpoint` at `.../dcr/register`, S256, and `none` as a token
  auth method. So Claude Code's standard `/mcp` authenticate applies.
- Responses expose `Retry-After` and `X-RateLimit-{Limit,Remaining,Reset}`
  headers; the exact limit is not published.
- No official documentation page for this endpoint was found on
  2026-11-05; the metadata's `resource_documentation` points at Atlassian's
  general remote-MCP page, which does not mention Trello. Tool names and
  token lifetimes are therefore not recorded here; read them from a session.
- This is a separate server from the Atlassian Rovo MCP server (`atlassian`,
  Jira and Confluence) that may also be configured on a machine. Different
  endpoint, different login; the skill tells people not to confuse the two.

Observed from a session on 2026-11-15 (closes the tool-name part of the #1
gate): the server exposes fifteen tools, `trelloRead{Board,Card,Checklist,
Inbox,List,Member,Planner,Workspace}`, `trelloWrite{Board,Card,Checklist,
Inbox,List,Planner}`, and `trelloSearch`, each with an `action` enum. IDs
are Atlassian ARIs (`ari:cloud:trello::card/workspace/<ws>/<id>`); most
read actions also accept a trello.com URL, write actions need the ARI.

### card-first skill (#2)

Shipped in 0.2.0 as `skills/card-first/SKILL.md` plus a `SessionStart`
hook (`hooks/hooks.json`, `scripts/card-first-nudge.sh`). Decisions, so
they are not re-litigated:

- **How it fires.** The hook, not a paragraph in `~/.claude/CLAUDE.md`,
  carries the trigger: it reads the project's `CLAUDE.local.md` and emits
  `additionalContext` telling Claude to invoke the skill when a work item
  starts (`on`), to ask once (`unset`), or nothing (`off`). Fixed strings
  only, no `jq`, exits 0 always, matcher `startup|resume|clear|compact` so
  the nudge survives compaction. `~/.claude/CLAUDE.md` keeps only the
  coordination rule with `issue-first` (one combined question when both
  apply).
- **Which board.** `card-first-board: <URL>` in `CLAUDE.local.md`; when
  unset and the member has exactly one open board, the skill uses it and
  records it. `card-first-list` (name) is recorded on the first create.
  The skill learns list roles (backlog, next-up, in progress, done,
  parents) from the board's own list names via `trelloReadBoard get`.
- **Search behavior** (verified on the `everything` board): `trelloSearch`
  requires every word of the query as a whole word, so a phrase finds
  nothing and single-word queries are the rule. `trelloReadCard
  list_by_board` returned 81 KB for an 81-card board; the skill uses
  `trelloReadBoard get` for list names and `list_by_list` for the semantic
  pass instead.
- **Writes.** Create (name, desc, list), move, add_comment, mark_done;
  labels only if already on the board and obvious; never due dates. Every
  write behind an explicit yes. Updates are batched: one offer when work
  lands or at wrap-up, not per turn.
- **With issue-first.** Both searches run before one combined question;
  the card description carries the issue URL; the issue is not edited for
  the card link.

### To do

- [x] Install from this checkout (done 2026-11-05, user scope; 0.2.0
      reinstalled 2026-11-15, cache path
      `~/.claude/plugins/cache/my-plugin-marketplace/trello/0.2.0`).
- [ ] Verification gate (#1): `/mcp` authentication and a listing call
      worked in a session on 2026-11-15 (tool names recorded above). Still
      missing: the consent page's scope list as shown to the user. Close
      #1 when that is noted here.
- [ ] Commit (`Refs #1 #2`), push, and settle #3 (rename the GitHub repo to
      match the marketplace name, or the reverse) before registering it
      anywhere but this machine.
- [ ] `card-first` (#2): shipped in 0.2.0, see the section above. Still to
      do before closing: try it interactively on a no-match item with
      create and with skip, and on the wrap-up update; then close #2.
- [ ] Later, if the bare tools prove awkward: a `trello` query skill with
      usage patterns, after some real use.

## Memory routing

Durable, portable, project-scoped facts go in a committed `.claude/memory/`
here once there is more than this file can hold comfortably (mirror the ATS
repo's `INDEX.md` convention and import it from this file). Machine-specific
facts stay in `~/.claude` memory. The issue-first and card-first settings
live in `CLAUDE.local.md`, never here.

## References

- Plugin reference: https://code.claude.com/docs/en/plugins-reference.md
- Marketplaces: https://code.claude.com/docs/en/plugin-marketplaces.md
- The ATS marketplace this copies: `~/workshop/ats-plugin-marketplace/CLAUDE.md`
  and its `.claude/memory/` (OAuth paths for plugin servers, local install
  shadowing a synced plugin, claude.ai sync following release tags).
