---
name: zotero
description: >-
  Use when resolving Zotero paper, collection, or tag references (including @z: links), or reading papers, annotations, and notes in the user's library or current Zotero selection. Covers reading and requested note-taking; use zotero-curation for imports or cleanup and project-bibliography for project collections or exports. Not for general web literature search without a Zotero request.
---

# Zotero access and reading

## Resolve the source

Use the owned `zotero-tools` CLI and check `ok` before using `data`; output is always JSON. It uses the Web API on both Mac and remote machines. `/zotero-login` continues to configure the shared private credential store; no key belongs in a shell command, conversation, or project file. If credentials are missing or rejected, ask the user to run that command interactively. Do not read or print the credential file to diagnose login.

Native Pi completion produces scoped API references. `metadata`, `children`, `notes`, and `collection-items` accept the corresponding full API URL and preserve its library identity. For key-only commands, scope explicitly:

```sh
zotero-tools --library user:USER_ID metadata KEY
```

Use the URL's numeric user ID, not `0`; group libraries use `--library group:GROUP_ID`. Do not replace a reference's library with the configured default.

- `.../items/KEY`: use `metadata URL`, `children URL`, or `notes URL`. Read attachments/pages only as needed.
- `.../collections/KEY`: use `collection-items URL --limit 20`. The collection scopes reading without requiring every PDF. Exclude subcollections unless requested.
- `.../tags/NAME`: URL-decode the final path segment exactly. For dot-only names, decode the value in `items/top?tag=NAME` instead. Use `--library user:USER_ID search --tag 'NAME' --limit 20`, quoting shell arguments to preserve punctuation. Keep only exact tag matches; API comparisons may ignore case or diacritics. Tags scope items rather than identifying a paper. API tag searches can miss literal names containing query operators such as `-` or `||`; state that limitation rather than reporting an exhaustive absence.

Legacy `zotero://select/library/items/KEY`, `zotero://select/library/collections/KEY`, and `http://127.0.0.1:23119/api/users/0/tags/NAME` references use the same operations through the configured web personal library. They do not encode an account ID; resolve that scope before proceeding if the source account is uncertain. Do not force local mode or library ID `0`.

Use keys and URLs as identity; labels are for readability. Unselected `@z:` text is a query, not a resolved key. State limits or unavailable sources rather than claiming exhaustive coverage. A reference alone never authorizes writes.

## Use selection and page tools when available

`zotero_context` and `zotero_view` are optional readonly tools, inactive globally unless enabled for the session or project. Follow their tool descriptions. Do not assume they are installed or change configuration to enable them unasked.

- Call `zotero_context` for "this paper," the current reader, or current selection. Do not poll it for unrelated library questions.
- Use its attachmentKey and libraryID as source identity. The reader bridge stays local; CLI follow-up uses the web API. Resolve library mapping first, especially for groups; bridge-local library IDs are not API user/group IDs. If a newly added paper or annotation is missing remotely, ask the user to let Zotero finish syncing rather than switching library access to local mode.
- Use `zotero_view` for figures, equations, tables, or layout missed by text. It takes an attachmentKey, a 1-based page, and an optional crop rect. Preserve library identity as supported. It does not annotate or change reader selection.
- If unavailable, resolve an explicit key/link through the CLI or ask which paper is meant. Do not substitute a similarly titled item.

## Read and explain

1. Inspect metadata and children first. Read `notes ITEM_KEY` and `annotations ATTACHMENT_KEY` when relevant. Distinguish the user's notes, the paper's claims, and your interpretation.
2. Read only needed attachments/pages. Synced Zotero Storage PDFs are downloadable without a desktop instance; attachment metadata alone does not prove remote availability. Use `find ATTACHMENT_KEY 'phrase'`, then `read ATTACHMENT_KEY --start-page N --end-page M` (physical PDF pages, 1-based). PDFs and page text are cached across commands/sessions; do not manually re-download or convert them. Use `--refresh` after a known source change or recent sync. For visual content, prefer the reader tool or use `image ATTACHMENT_KEY --start-page N --out TEMP.png` and read that temporary PNG. Keep generated files outside the repository. WebDAV/linked-file-only attachments require syncing a Zotero Storage copy or explicitly supplied content; do not silently switch access modes.
3. Answer from pages actually read. Cite the item and page or annotation when available, mark quotations, and state missing access or unexamined sections. An abstract or metadata alone does not support a full-paper reading claim.

Lead with the answer to the user's question. Include source limits where they affect the answer, without narrating retrieval.

## Save notes only when requested

Draft notes in the conversation by default. Before saving, inspect the destination and existing content. Preserve notes and annotations; prefer a new note or agreed append over replacement. Save an authorized new note with `note PARENT_KEY --file TEMP.html --commit` (without `--commit`, it only previews). Read back the saved note and report its item/note key.

Explaining or summarizing a paper does not authorize saving a note.

For imports, metadata corrections, or duplicates, load [Zotero curation](../zotero-curation/SKILL.md). For project collections, tag meanings, or exports, load [project bibliography](../project-bibliography/SKILL.md).
