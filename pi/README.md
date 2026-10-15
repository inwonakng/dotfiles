# Personal Pi extensions

`~/.pi` links to this directory. Pi discovers the standalone extensions in
`agent/extensions/`; no extra `extensions` setting or console package is needed:

- `question.ts`: multiple-choice questions plus a freehand option. Uses standard
  Pi `select`/`input` dialogs in both the native UI and RPC clients. Cancelling
  freehand input returns to choices; cancelling choices ends the question.
  `PI_INTERACTION_MODE=noninteractive` disables interaction even in RPC children.
- `todowrite.ts`: structured task lists and `/todos`. Reconstructs existing
  `todowrite` result details from the current session branch. The console's todo
  rendering is optional; the extension also works in native Pi.
- `litellm.ts`: the `litellm` provider, login, model discovery, Responses capability
  probing, and `/litellm-refresh`. Credentials stay in `agent/auth.json` or
  `LITELLM_BASE_URL`/`LITELLM_API_KEY`; they are not part of the extension source.
  Cache files remain `litellm-provider-models.json` (and legacy
  `litellm-models.json`) in the Pi agent directory. `LITELLM_OFFLINE=1` or
  `PI_OFFLINE=1` disables discovery/refresh network calls;
  `LITELLM_DISCOVERY_TIMEOUT_MS` retains its existing behavior.
- `web-search/`: keyless search and page extraction with private helpers and npm
  dependencies. Install these after cloning:

  ```sh
  cd ~/.pi/agent/extensions/web-search
  npm ci --ignore-scripts --legacy-peer-deps
  ```

Pi supplies its own host libraries and `typebox`; do not install copies here.
The console package remains separately installed through `agent/settings.json`.
It owns access control, subagents, workspace/history/tree integration, titles,
notifications, and Codex usage. Do not also load copies of these personal
extensions from a second package or `extensions` entry.

## Native tool selection

Optional tools register with `defaultActive: false`. Global `agent/settings.json`
enables the existing tools alongside Pi's ordinary built-ins:

```json
{
  "defaultTools": ["+spawn", "+spawn_control", "+workspace", "+question", "+todowrite", "+web_search", "+web_fetch"]
}
```

In a trusted project's `.pi/settings.json`, subtract tools that project does not
need, without unloading their extensions or commands:

```json
{
  "defaultTools": ["-spawn", "-spawn_control", "-todowrite"]
}
```

These tools use direct exposure, not deferred exposure, so inactive tools are not
callable/discoverable from codemode either. Codemode/tool search are not enabled by
this setup. Startup selection is not a permanent exclusion or permission gate:
CLI selections can override it, and other extensions can activate tools. Restart
a session after removing tools in settings; `/reload` does not deactivate tools
that were already active. No custom loadout/filtering extension is installed.

Skills remain enabled globally. Pi's `skills` setting filters resource paths,
not skill names. For a globally discovered skill, the installed resolver needs an
explicit project entry as well as its exclusion, for example:

```json
{
  "skills": [
    "~/.pi/agent/skills/frontend-web/SKILL.md",
    "-~/.pi/agent/skills/frontend-web/SKILL.md"
  ]
}
```

This unloads the skill, including its `/skill:frontend-web` command. It does not
prevent reading its file or remove instructions already loaded in the transcript.
The skill frontmatter `disable-model-invocation: true` instead hides automatic
advertisement while retaining manual invocation, but is not project-specific.

## Web tools

`web_search(query, limit)` queries Exa, Parallel, Firecrawl, and Keenable
concurrently, without API keys or model-provider credentials. It interleaves
results, deduplicates URLs (ignoring fragments, preserving query parameters), and
reports provider provenance and partial failures. Snippets, excerpts, and page
content are returned without local summarization or relevance filtering. The
default limit is 5; supported limits are 1–20. Anonymous services may throttle
requests; one provider's failure does not discard the others' results.

`web_fetch(url, maxChars)` first retrieves the page directly and converts readable
HTML to Markdown, preserving links and document structure. If that fails, it tries
hosted extraction providers in order. Results retain requested/returned URLs,
provider, failures, format, `contentKind` (page or excerpts), and truncation
metadata. `totalChars` counts extracted text before local truncation, not
necessarily the entire original page. The default is 12,000 characters; supported
limits are 1,000–50,000. Requests have a 30-second deadline per provider and respect
cancellation.

Provider selection belongs in Pi's `settings.json`, globally or in a trusted
project, not in `pi-console-config.yaml`:

```json
{
  "webSearch": {
    "providers": ["exa", "parallel", "firecrawl", "keenable"]
  }
}
```

Omitting the field uses that default order. Lists must be non-empty, have no
duplicates, and contain only those four names. The effective settings are read on
each call; use `/reload` or restart to make file edits effective in Pi. Project
lists replace global lists. Search sends the query to every selected provider;
hosted fetching sends the URL only after direct fetching fails. No hosted-service
signup or browser installation is required.
