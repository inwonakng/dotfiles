---
name: zotero
description: "Use when the user refers to papers, collections, or tags in their Zotero library, including Zotero links inserted by @z: completion. Not for general web literature search without a Zotero request."
---

# Zotero references

Use `zotero-cli --json` for library reads. Check `ok` before using `data`.
Completion references target the local personal library: prefix commands with
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
