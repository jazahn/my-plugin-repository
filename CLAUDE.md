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
  skills/<skill>/SKILL.md           frontmatter name = invocation name, /<plugin>:<skill>
CLAUDE.local.md                     per-machine, excluded via .git/info/exclude (issue-first setting)
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
script, no hook. It works only when the remote server implements the MCP
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

### To do

- [ ] Verification gate: install from this checkout, `/mcp` authenticate
      `trello`, call one listing tool, and record the observed tool names
      and the consent page's scope list here.
- [ ] Commit, push, and decide whether to rename the GitHub repo to match
      the marketplace name (or the reverse) before registering it anywhere
      but this machine.
- [ ] Later, if the bare tools prove awkward: a `trello` query skill with
      usage patterns, after some real use.

## Memory routing

Durable, portable, project-scoped facts go in a committed `.claude/memory/`
here once there is more than this file can hold comfortably (mirror the ATS
repo's `INDEX.md` convention and import it from this file). Machine-specific
facts stay in `~/.claude` memory. The issue-first setting lives in
`CLAUDE.local.md`, never here.

## References

- Plugin reference: https://code.claude.com/docs/en/plugins-reference.md
- Marketplaces: https://code.claude.com/docs/en/plugin-marketplaces.md
- The ATS marketplace this copies: `~/workshop/ats-plugin-marketplace/CLAUDE.md`
  and its `.claude/memory/` (OAuth paths for plugin servers, local install
  shadowing a synced plugin, claude.ai sync following release tags).
