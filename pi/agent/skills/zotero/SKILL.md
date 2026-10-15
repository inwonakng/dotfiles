---
name: zotero
description: "Use when resolving Zotero paper, collection, or tag references (including @z: links), or reading papers, annotations, and notes in the user's library or current Zotero selection. Covers reading and requested note-taking; use zotero-curation for imports or cleanup and project-bibliography for project collections or exports. Not for general web literature search without a Zotero request."
---

# Zotero Access and Reading

## Resolve the source

Use `zotero-cli --json` for library reads. Check `ok` before using `data`.
The following native completion references target the local personal library: prefix their read commands with
`env ZOTERO_LOCAL=true ZOTERO_LIBRARY_TYPE=user ZOTERO_LIBRARY_ID=0 ZOTERO_BACKEND=sqlite`
so an unrelated CLI default cannot select a group library or API search backend.

- `zotero://select/library/items/KEY`: use `get metadata KEY`, `get children KEY`,
  or `notes list --item-key KEY`. Read the attachment/page range only as needed.
- `zotero://select/library/collections/KEY`: use `get collection-items KEY --limit 20`;
  this scopes the reading set, not a request to load every PDF. It excludes
  subcollections unless the user asks for them.
- `http://127.0.0.1:23119/api/users/0/tags/NAME`: URL-decode the final path
  segment exactly. Dot-only names use `items/top?tag=NAME` instead; decode that value.
  Use `search --mode advanced --conditions '[{"field":"tag","operation":"is","value":"NAME"}]' --limit 20`;
  construct the JSON with an encoder and quote shell arguments, preserving punctuation.
  Keep only items whose tags equal the decoded name exactly (CLI comparisons can
  ignore case/diacritics). These are scopes, not papers. If SQLite is unavailable,
  report that API fallback can miss names containing query operators (`-`, `||`).

Keys/URLs identify the source; labels are only for readability. Unselected `@z:`
text is a query, not a resolved key. State limits or unavailable sources rather
than claiming exhaustive coverage. A reference alone does not authorize Zotero writes.

## Current selection and page images

`zotero_context` and `zotero_view` are optional, read-only tools, inactive globally
unless enabled for the session or project. Follow their available tool descriptions;
do not assume they are installed or enable them by changing configuration unasked.

- Call `zotero_context` when the user refers to "this paper", the current reader,
  or the current Zotero selection. Do not poll it for unrelated library questions.
- Use the returned attachmentKey and libraryID to identify the actual source.
  They do not imply that the CLI's personal-library defaults target the same
  library. Resolve the library mapping before CLI follow-up, especially for groups;
  do not assume a bridge-local libraryID equals an API group ID.
- `zotero_view` renders a given attachmentKey at a 1-based page, with an optional
  rect for a crop. Use it for figures, equations, tables, or layout that text misses.
  Keep library identity attached to the request as the tool supports it. It does
  not create annotations or change the reader selection.
- If tools are unavailable, resolve an explicit key/link through the CLI or ask
  which paper the user means. Do not silently substitute a similarly titled item.

## Read and take notes

1. Inspect metadata and children first. Read existing notes with `notes list` and
   annotations with `annotations list` when relevant; distinguish the user's notes
   from the paper's claims and your own interpretation.
2. Read only the needed attachment/pages. Use `read --find` to locate a passage,
   then a bounded page range; use images when extraction loses mathematical or
   visual content. Distinguish PDF page indices from printed page labels.
3. Ground explanations in the pages actually read. Cite the item and page or
   annotation when available, identify quotations, and state missing access or
   unexamined sections. Metadata or an abstract alone is not a full-paper reading.
4. Draft notes in the conversation unless saving is requested. Before a requested
   save, inspect the destination and existing note content. Preserve existing notes
   and annotations; prefer a new note or an agreed append over replacing content.
   Read back the saved note and report its item/note key. A request to explain or
   summarize a paper is not by itself a request to save a note in Zotero.

For imports, metadata correction, or duplicates, load
[zotero-curation](../zotero-curation/SKILL.md). For project collection structure,
existing tag meanings, or bibliography exports, load
[project-bibliography](../project-bibliography/SKILL.md).
