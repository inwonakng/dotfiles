# Zotero research workspace

This directory is for reading papers, maintaining the Zotero library, and managing
research-project bibliographies through ordinary Pi/pi-console. It is not a
separate Pi profile. Keep global provider, permission, and interface configuration.

## Reader context

When I refer to "this paper", "this page", or a passage/area selected in Zotero,
call `zotero_context` to resolve the reference at that moment. Do not fetch context
or images automatically at session startup. An explicit paper key/link takes
precedence over whatever happens to be open.

Use `zotero_view` only when seeing a figure, equation, table, or area helps answer
the request. Pass the attachment key and `item.library.localID` from the current
context snapshot. Call the image tool directly, not through codemode. Images are
sent to the model provider; capture only the relevant page/region. A selected
annotation crop shows underlying PDF content, not the annotation's overlay.
If the bridge is unavailable, ask for a paper reference or pasted passage rather
than guessing what is open. Reading Mode and non-PDF selections may lack geometry;
report that limitation instead of using a previous selection.

Reader context includes library scope. Do not pass a group-library key to a CLI
command pinned to the personal library. Keep physical PDF page numbers (1-based)
separate from printed page labels.

## Library work

Use the existing `zotero-cli` in web mode for searches, imports, metadata,
collections, tags, notes, and synced Zotero Storage PDFs on every machine.
`/zotero-login` configures its shared machine-local credentials. Keep the reader
bridge local; do not force library commands to localhost or library ID `0`.
Unsynced desktop changes may not yet be available through the web API.
New papers require independently retrieved official publication
metadata when available; a citation in a repository/README is a clue, not the
preferred citation source. Reuse existing tags with their existing meaning; ask
before inventing tags or a new tag scheme.

A reference or reader snapshot is not authorization to change the library. Ask
before merges, deletions, broad retagging, or replacing existing notes. Keep notes,
PDFs, annotations, citation keys, and unrelated collection memberships intact.
Verify requested writes by reading them back, and report partial failures.

## Research-project bibliographies

This is a shared research workspace, not an implicit bibliography for every
project. Obtain the project's own instructions/path when a task concerns one.
Record its library, collection key/path, subcollection scope, inclusion criteria,
existing tag meanings, export path, and citation-key convention there. Do not
invent a universal hierarchy or tag taxonomy in this directory.
