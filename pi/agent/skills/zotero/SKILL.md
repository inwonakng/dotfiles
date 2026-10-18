---
name: zotero
description: "Use when resolving Zotero paper, collection, or tag references (including @z: links), or reading papers, annotations, and notes in the user's library or current Zotero selection. Covers reading and requested note-taking; use zotero-curation for imports or cleanup and project-bibliography for project collections or exports. Not for general web literature search without a Zotero request."
---

# Zotero access and reading

## Resolve the source

Use `zotero-cli --json` for library reads and check `ok` before using `data`.

Native completion references below target the local personal library. Prefix their read commands with:

```sh
env ZOTERO_LOCAL=true ZOTERO_LIBRARY_TYPE=user ZOTERO_LIBRARY_ID=0 ZOTERO_BACKEND=sqlite
```

This prevents unrelated CLI defaults from selecting a group library or API search backend.

- `zotero://select/library/items/KEY`: use `get metadata KEY`, `get children KEY`, or `notes list --item-key KEY`. Read attachments/pages only as needed.
- `zotero://select/library/collections/KEY`: use `get collection-items KEY --limit 20`. The collection scopes reading without requiring every PDF. Exclude subcollections unless requested.
- `http://127.0.0.1:23119/api/users/0/tags/NAME`: URL-decode the final path segment exactly. For dot-only names, decode the value in `items/top?tag=NAME` instead. Use `search --mode advanced --conditions '[{"field":"tag","operation":"is","value":"NAME"}]' --limit 20`. Build JSON with an encoder and quote shell arguments to preserve punctuation. Keep only items with an exact tag match; CLI comparisons may ignore case or diacritics. Tags scope items rather than identifying a paper. If SQLite is unavailable, state that API fallback can miss names with query operators such as `-` or `||`.

Use keys and URLs as identity; labels are for readability. Unselected `@z:` text is a query, not a resolved key. State limits or unavailable sources rather than claiming exhaustive coverage. A reference alone never authorizes writes.

## Use selection and page tools when available

`zotero_context` and `zotero_view` are optional readonly tools, inactive globally unless enabled for the session or project. Follow their tool descriptions. Do not assume they are installed or change configuration to enable them unasked.

- Call `zotero_context` for "this paper," the current reader, or current selection. Do not poll it for unrelated library questions.
- Use its attachmentKey and libraryID as source identity. Resolve library mapping before CLI follow-up, especially for groups; bridge-local library IDs are not necessarily API group IDs or the CLI's personal-library target.
- Use `zotero_view` for figures, equations, tables, or layout missed by text. It takes an attachmentKey, a 1-based page, and an optional crop rect. Preserve library identity as supported. It does not annotate or change reader selection.
- If unavailable, resolve an explicit key/link through the CLI or ask which paper is meant. Do not substitute a similarly titled item.

## Read and explain

1. Inspect metadata and children first. Read `notes list` and `annotations list` when relevant. Distinguish the user's notes, the paper's claims, and your interpretation.
2. Read only needed attachments/pages. Locate passages with `read --find`, then use a bounded page range. Use images for lost mathematical or visual content, and distinguish PDF indices from printed page labels.
3. Answer from pages actually read. Cite the item and page or annotation when available, mark quotations, and state missing access or unexamined sections. An abstract or metadata alone does not support a full-paper reading claim.

Lead with the answer to the user's question. Include source limits where they affect the answer, without narrating retrieval.

## Save notes only when requested

Draft notes in the conversation by default. Before saving, inspect the destination and existing content. Preserve notes and annotations; prefer a new note or agreed append over replacement. Read back the saved note and report its item/note key.

Explaining or summarizing a paper does not authorize saving a note.

For imports, metadata corrections, or duplicates, load [Zotero curation](../zotero-curation/SKILL.md). For project collections, tag meanings, or exports, load [project bibliography](../project-bibliography/SKILL.md).
