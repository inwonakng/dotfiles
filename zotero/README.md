# Zotero research agent

Use ordinary Pi or pi-console in `~/agents/zotero`, with the same global providers,
credentials, access control, and UI. The project adds reader tools and narrows the
active tools/advertised skills; it does not create another Pi profile or sandbox.

## Set up

From the **normal dotfiles checkout**, not a temporary task worktree:

```sh
bash ~/dotfiles/scripts/setup/zotero.sh
```

This links `pi/projects/zotero/AGENTS.md` and `settings.json` into the project and
builds `~/dotfiles/zotero/pi-zotero-reader.xpi` in that checkout's `zotero/`
directory. The generated XPI is ignored by Git.
It refuses to replace regular project configuration files. It does not install
plugins, change the library, or copy credentials. The setup script packages the
two plugin files with `zip`; no Python, npm dependencies, or PDF packages are needed.

In Zotero **10.0.x**:

1. Tools → Plugins → gear → **Install Plugin From File**; select the `.xpi`.
2. Settings → Advanced → **Allow other applications on this computer to
   communicate with Zotero**.
3. Start a **new** Pi/pi-console session in `~/agents/zotero` and trust that
   project's configuration. No special Pi launch flags are required.

Examples: "Explain this paper's identification strategy", "What is happening in
this selected figure?", "Save this explanation as a note on this paper". Context
is fetched when the request needs it; note creation still requires a request to
write. Global Zotero skills work in research project directories too, without
reader tools or this workspace.

Rebuild and reinstall the XPI after editing `bridge/bootstrap.js` or
`bridge/manifest.json`; updates are manual. Zotero requires an `update_url`, which
points to this repository's raw `master` copy of `zotero/updates.json`. That file
has an empty updates list, so it advertises no automatic updates. Commit and push
`zotero/updates.json` to `master` to make the URL available; local setup does not
publish it.

Disable/remove the plugin to remove the endpoints. To undo
project setup, remove only the two symlinks and the generated XPI; leave your other
project files alone.

## Reader tools

`pi/agent/extensions/zotero-reader.ts` registers both tools with
`defaultActive: false`. They do not connect at startup. Context has direct
exposure and is not callable through codemode while inactive. View is model-only:
call it directly so its image blocks reach the model rather than being reduced
to text by codemode. Project `defaultTools` enables
these alongside file/shell, web, question, task-list and codemode tools. It omits
subagents/workspaces and disables built-in MCP in this project. Existing console
extensions remain loaded for permissions and UI; this is not process isolation.
Restart to apply removals; `/reload` does not deactivate already-active tools.

- **`zotero_context {}`** returns a fresh timestamped reader or library snapshot.
  Reader snapshots include item/library identity, attachment key, physical page
  (1-based), printed label, current selected text, and up to five selected saved
  annotations. No PDFs or images are captured. Library snapshots contain up to
  five selected item summaries and the selected collection. Limits are explicit.
- **`zotero_view`** requires `attachmentKey` and `libraryID` from a fresh snapshot
  (`item.library.localID`, not the web API group ID). `target` is:
  - `page`: optional physical `page`; optional normalized top-left
    `rect: [x,y,width,height]`, entirely inside the displayed page.
  - `selection`: up to three current PDF text-selection bounding regions.
  - `annotation`: `annotationKey` for a currently selected saved annotation.

View results contain source context, PDF-coordinate crop rectangles and PNG image
blocks (including both pages of a selected cross-page annotation). They show PDF content, not Zotero UI, annotation overlays, or text-shaped
masks. No image files or annotations are written. Capture refuses a changed
paper/library and does not fall back to a different open PDF. A capture uses the
reader state it resolved at request time. Tool results can therefore be stale if
you switch papers afterward; fetch context again for a new reference.

Only PDF rendering is supported. Reading Mode/non-PDF views can lack selection
geometry; an unavailable selection is reported instead of replaying a cached
popup. A Zotero dialog can obscure the active reader: focus the library/reader
and retry. The bridge uses private reader APIs inspected in **Zotero 10.0.6**,
including `_lastView`, `_selectionRanges`, and `_pdfRenderer.renderRegionCrops`.
They may change; failures must be surfaced rather than guessed around. Upstream
API context: [Zotero 10 developer notes](https://www.zotero.org/support/dev/zotero_10_for_developers)
and [plugin lifecycle](https://www.zotero.org/support/dev/zotero_7_for_developers).
The bridge is maintained here, independently of the third-party chat panel.

## Security and privacy

The plugin adds two POST endpoints to Zotero's existing loopback server:
`/pi-zotero/context` and `/pi-zotero/view`. Requests require a random bearer token,
reject any `Origin` header, and expose no eval, arbitrary path/URL access or library
write operations. Zotero itself checks Host/loopback binding. Do not expose its
server through a network proxy. The Pi client reads the token from
`~/.local/state/pi-zotero/bridge.json`. This is automatic connection state, not
user-maintained configuration. Both components use this fixed home-relative path
rather than `XDG_STATE_HOME` or `TMPDIR`, which can differ between a Dock-launched
Zotero and a terminal-launched Pi.

The plugin owns the file: it atomically records the protocol version, Zotero port,
and a fresh random token on startup, using directory permissions `0700` and file
permissions `0600`. Pi only reads it, freshly for each request; it never creates or
edits credentials. On normal shutdown the plugin removes the file only if the
token still belongs to that instance. A stale file after a crash does not imply a
reachable bridge; Pi reports connection failures.

That file is outside the repository; never include it in prompts or commits.
Use one Zotero instance/profile at a time with this shared state location. After
updating from the old `~/.config/pi-zotero/bridge.json` location, reinstall the new
XPI and restart Pi so both components use the state path. No token migration or
manual configuration is needed.

Context text is capped, images are limited to three and 12 MiB total PNG data
(16 MiB base64), the client bounds response size, and overlapping image renders are
refused. Reader selection is read on request; there is no watcher or background
capture. No session-start context injection takes place.

**Anything returned by a tool can enter the Pi transcript and be sent to the model
provider.** Images are only requested on demand. Zotero debug logging at level 5
can record HTTP headers (including the bearer token) and response bodies. Do not
share unredacted debug logs. Disabling tools limits model exposure, not shell
access or OS permissions; project instructions and inactive tools are not a
security sandbox.

Library data operations continue to use `zotero-cli`, not this reader bridge. See
`pi/agent/skills/zotero`, `zotero-curation`, and `project-bibliography`. Reads can
work locally; writes require separately authorized local API writes (Zotero 10)
or configured web API credentials. Setup does not grant write authorization.

## Validation boundaries

The XPI can be packaged and its endpoint, selection, crop and tool contracts
checked outside Zotero using throwaway probes. Those checks do not establish live
reader compatibility. After installation, manually exercise: main-window and
standalone/split readers; cleared and cross-page selections; selected area
annotations; full-page and cropped images on rotated PDFs; changed-paper errors;
and note creation/read-back only when requested. Do not call the bridge live-tested
until those checks have actually run.
