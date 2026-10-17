# Zotero research agent

Read papers and manage your Zotero library through ordinary Pi or pi-console.
Use `~/agents/zotero` when you want the agent to see which paper, passage, or
figure you have selected in Zotero.

- **First time:** follow [Setup](#setup).
- **Already installed:** open Zotero, start Pi in `~/agents/zotero`, and ask about
  the paper you are reading.
- **Something is unavailable:** see [Troubleshooting](#troubleshooting).

## Everyday use

Open a PDF in Zotero, then start a session:

```sh
cd ~/agents/zotero
pi
```

You can use pi-console in the same directory instead. No special launch flags
are needed.

Example requests:

- "Explain this paper's identification strategy."
- "Explain the passage I selected."
- "What is happening in this selected figure?"
- "Find papers in my library about causal discovery."
- "Save this explanation as a new note on this paper."

The agent fetches the current selection only when your request needs it. It does
not watch Zotero or capture pages in the background. Summarizing a paper does not
authorize saving a note; ask explicitly when you want a library change.

**Paper text and images returned to Pi can enter the transcript and be sent to
the model provider.**

## Setup

You need Zotero **10.0.x**, Pi or pi-console, and `zotero-cli` for library work.
The setup script below configures the reader integration; it does not install
those applications.

### Build the plugin and link the workspace

Run this from your normal dotfiles checkout, **not a temporary task worktree**:

```sh
bash ~/dotfiles/scripts/setup/zotero.sh
```

The script links the workspace configuration into `~/agents/zotero` and builds:

```text
~/dotfiles/zotero/pi-zotero-reader.xpi
```

It requires `zip`, refuses to replace regular workspace configuration files, and
does not install the plugin, change your library, or copy credentials. Packaging
requires no Python, npm dependencies, or PDF packages.

### Enable the integration in Zotero

1. Open **Tools > Plugins > gear > Install Plugin From File** and choose the XPI.
2. Enable **Settings > Advanced > Allow other applications on this computer to
   communicate with Zotero**.
3. Start a **new** Pi/pi-console session in `~/agents/zotero` and trust the
   project's configuration.

## Reading and library tools

The integration has separate tools for library access and the open Zotero reader:

| Tool | Purpose |
| --- | --- |
| `zotero-cli` | Search the library; read metadata, PDF text, notes, and annotations; perform requested imports, edits, and exports. |
| `zotero_context` | Identify the currently selected paper, page, passage, or saved annotations. |
| `zotero_view` | Show the model a PDF page or crop, such as a figure, table, or equation. |

The reader bridge is read-only. Library changes go through `zotero-cli` and
require separately authorized local API writes (Zotero 10) or configured web API
credentials. Setup does not grant write authorization.

The global skills also work in other research directories without the reader
bridge:

- [zotero](../pi/agent/skills/zotero/SKILL.md): paper references, reading, and requested note-taking.
- [zotero-curation](../pi/agent/skills/zotero-curation/SKILL.md): imports, metadata correction, and duplicates.
- [project-bibliography](../pi/agent/skills/project-bibliography/SKILL.md): project collections, existing tags, and bibliography exports.

### PDF text and images

`zotero-cli read` extracts text automatically; the agent does not need to convert
the PDF manually. Ordinary CLI reads do not keep a persistent Markdown conversion
for reuse across commands. The installed CLI has a process-local parse cache and
a separate transient cache for semantic indexing, not a permanent reading cache.

Text extraction can lose equations or visual structure. For those passages, the
agent can request an image. `zotero_view` renders PDF content directly from Zotero,
without saving image files or showing Zotero's UI or annotation overlays. CLI
image reads are another option and write PNG files to disk.

## Troubleshooting

| Symptom | Action |
| --- | --- |
| Reader bridge unavailable | Open Zotero, enable local communication, and check that the reader plugin is enabled. |
| Reader tools missing | Start a new session in `~/agents/zotero` and trust its configuration. |
| Current paper or selection unavailable | Focus the Zotero library or PDF reader, dismiss dialogs, and retry. |
| Selection image unavailable | Use the PDF view rather than Reading Mode. Non-PDF views may lack selection geometry. |
| Paper changed during a request | Ask again so the agent fetches fresh context; it will not substitute another open PDF. |
| Library write refused | Check the CLI's write authorization. The reader plugin cannot write to the library. |

If the bridge remains unavailable, provide an explicit Zotero paper link/key or
paste the passage. Library access through the CLI is independent of the bridge.

## Updates and removal

After changing `bridge/bootstrap.js` or `bridge/manifest.json`, rerun setup from
the normal checkout and reinstall the XPI. Plugin updates are manual.

To remove the integration, disable/remove the plugin and remove only these setup
artifacts, leaving other workspace files alone:

- `~/agents/zotero/AGENTS.md` symlink
- `~/agents/zotero/.pi/settings.json` symlink
- `~/dotfiles/zotero/pi-zotero-reader.xpi`

## Technical reference

These details are for maintaining or debugging the integration, not everyday use.

<details>
<summary>Reader tool inputs and limits</summary>

`zotero_context {}` returns a fresh timestamped snapshot, without images:

- In the reader: item/library identity, attachment key, physical page (1-based),
  printed page label, selected text, and up to five selected saved annotations.
- In the library: up to five selected item summaries and the selected collection.

`zotero_view` requires `attachmentKey` and `libraryID` from fresh context. Use
`item.library.localID`, not a web API group ID. Supported targets:

| Target | Parameters |
| --- | --- |
| `page` | Optional physical `page` and normalized top-left `rect: [x,y,width,height]`, entirely inside the displayed page. |
| `selection` | Up to three current text-selection bounding regions. |
| `annotation` | `annotationKey` of a currently selected saved annotation. Cross-page annotations can return both pages. |

Results include source context, PDF-coordinate crop rectangles, and PNG images.
They show rectangular PDF regions, not text-shaped masks. The bridge rejects a
changed paper/library. Results reflect state resolved at request time and can
become stale after a paper switch.

Text is capped. Images are limited to three and 12 MiB total PNG data (16 MiB
base64); the client also bounds response size. Overlapping renders are refused.

</details>

<details>
<summary>Pi configuration and source files</summary>

- [Project instructions](../pi/projects/zotero/AGENTS.md)
- [Project settings](../pi/projects/zotero/settings.json)
- [Reader tool extension](../pi/agent/extensions/zotero-reader.ts)
- [Zotero plugin](bridge/bootstrap.js) and [manifest](bridge/manifest.json)
- [Setup script](../scripts/setup/zotero.sh)

This is ordinary Pi with the same global providers, credentials, permissions,
and UI, not a separate profile or sandbox. The project enables reader tools
alongside file/shell, web, question, task-list, and codemode tools. It omits
subagents/workspaces and disables built-in MCP; console permission/UI extensions
remain loaded.

Both reader tools default to inactive globally and make no startup connection.
Inactive context is not callable through codemode. Call `zotero_view` directly,
not through codemode, so its image blocks reach the model. Restart after changing
the active tool set: `/reload` does not deactivate already-active tools.

</details>

<details>
<summary>Connection security and privacy</summary>

The plugin exposes POST endpoints `/pi-zotero/context` and `/pi-zotero/view` on
Zotero's existing loopback server. They require a random bearer token, reject
requests with an `Origin` header, and expose no eval, arbitrary path/URL access,
or library writes. Zotero checks Host/loopback binding. Do not expose the server
through a network proxy.

Connection state is automatic, not user-maintained configuration:

```text
~/.local/state/pi-zotero/bridge.json
```

The plugin atomically writes the protocol version, port, and a fresh random token
on startup, with directory permissions `0700` and file permissions `0600`. Pi
reads the file afresh for each request and never edits credentials. Normal
shutdown removes it only if its token still belongs to that plugin instance; a
stale file after a crash does not establish connectivity.

Use one Zotero instance/profile at a time. Both components use this fixed path
rather than `XDG_STATE_HOME` or `TMPDIR`, whose values can differ between Dock and
terminal launches. If upgrading from `~/.config/pi-zotero/bridge.json`, reinstall
the new XPI and restart Pi; no manual token migration is needed.

Never include the state file in prompts or commits. Zotero debug logging at
level 5 can record bearer tokens and response bodies; do not share unredacted
logs. Inactive tools and project instructions limit model exposure, not shell
access or OS permissions.

</details>

<details>
<summary>Compatibility and maintenance checks</summary>

The bridge uses private Zotero reader APIs inspected in **10.0.6**, including
`_lastView`, `_selectionRanges`, and `_pdfRenderer.renderRegionCrops`. These can
change; failures must be reported rather than replaced with guessed or cached
selections. This bridge is maintained independently of the third-party chat panel.

Packaging and throwaway probes outside Zotero can check endpoint, selection,
crop, and tool contracts. They do not prove live reader compatibility. After
installation, manually check:

- Main-window, standalone, and split readers.
- Cleared and cross-page selections; selected area annotations.
- Full-page and cropped images on rotated PDFs; changed-paper errors.
- Requested note creation and read-back, only with authorization.

Do not describe the bridge as live-tested unless those checks have run.

The manifest's required `update_url` points to the repository's raw `master`
copy of [updates.json](updates.json). Its empty updates list advertises no
automatic updates. The file must be committed and pushed to `master` for the URL
to be available; setup does not publish it.

Upstream references: [Zotero 10 developer notes](https://www.zotero.org/support/dev/zotero_10_for_developers)
and [plugin lifecycle](https://www.zotero.org/support/dev/zotero_7_for_developers).

</details>
