---
name: zotero
description: "Use when resolving Zotero paper, collection, or tag references (including @z: links), or reading papers, annotations, and notes in the user's library or current Zotero selection. Covers reading and requested note-taking; use zotero-curation for imports or cleanup and project-bibliography for project collections or exports. Not for general web literature search without a Zotero request."
---

# Zotero access and reading

## Resolve the source

Use `zotero-cli --json` for library reads and check `ok` before using `data`. Use web mode on both Mac and remote machines, including requested library writes. `/zotero-login` saves the API key and user ID in the CLI's native machine-local configuration; no key belongs in a shell command, conversation, or project file. If credentials are missing or rejected, ask the user to run that command interactively. Do not read or print the credential file to diagnose login.

Native Pi completion produces `https://api.zotero.org/users/USER_ID/...` references. Scope their CLI commands to the user ID in the URL:

```sh
env ZOTERO_LOCAL=false ZOTERO_LIBRARY_TYPE=user ZOTERO_LIBRARY_ID=USER_ID ZOTERO_BACKEND=api zotero-cli --json ...
```

Replace `USER_ID` with the URL's numeric ID, not `0`. This preserves the reference's library identity without putting the key in the command.

- `.../items/KEY`: use `get metadata KEY`, `get children KEY`, or `notes list --item-key KEY`. Read attachments/pages only as needed.
- `.../collections/KEY`: use `get collection-items KEY --limit 20`. The collection scopes reading without requiring every PDF. Exclude subcollections unless requested.
- `.../tags/NAME`: URL-decode the final path segment exactly. For dot-only names, decode the value in `items/top?tag=NAME` instead. Use `search --mode advanced --conditions '[{"field":"tag","operation":"is","value":"NAME"}]' --limit 20`. Build JSON with an encoder and quote shell arguments to preserve punctuation. Keep only items with an exact tag match; CLI comparisons may ignore case or diacritics. Tags scope items rather than identifying a paper. API tag searches can miss literal names containing query operators such as `-` or `||`; state that limitation rather than reporting an exhaustive absence.

Legacy `zotero://select/library/items/KEY`, `zotero://select/library/collections/KEY`, and `http://127.0.0.1:23119/api/users/0/tags/NAME` references use the same operations through the configured web personal library. They do not encode an account ID; resolve that scope before proceeding if the source account is uncertain. Do not force local mode or library ID `0`.

Use keys and URLs as identity; labels are for readability. Unselected `@z:` text is a query, not a resolved key. State limits or unavailable sources rather than claiming exhaustive coverage. A reference alone never authorizes writes.

## Use selection and page tools when available

`zotero_context` and `zotero_view` are optional readonly tools, inactive globally unless enabled for the session or project. Follow their tool descriptions. Do not assume they are installed or change configuration to enable them unasked.

- Call `zotero_context` for "this paper," the current reader, or current selection. Do not poll it for unrelated library questions.
- Use its attachmentKey and libraryID as source identity. The reader bridge stays local; CLI follow-up uses the web API. Resolve library mapping first, especially for groups; bridge-local library IDs are not API user/group IDs. If a newly added paper or annotation is missing remotely, ask the user to let Zotero finish syncing rather than switching library access to local mode.
- Use `zotero_view` for figures, equations, tables, or layout missed by text. It takes an attachmentKey, a 1-based page, and an optional crop rect. Preserve library identity as supported. It does not annotate or change reader selection.
- If unavailable, resolve an explicit key/link through the CLI or ask which paper is meant. Do not substitute a similarly titled item.

## Read and explain

1. Inspect metadata and children first. Read `notes list` and `annotations list` when relevant. Distinguish the user's notes, the paper's claims, and your interpretation.
2. Read only needed attachments/pages. Synced Zotero Storage attachments are downloadable without a desktop instance; attachment metadata alone does not prove the file has uploaded. Locate passages with `read --find`, then use a bounded page range. Use images for lost mathematical or visual content, and distinguish PDF indices from printed page labels.
3. Answer from pages actually read. Cite the item and page or annotation when available, mark quotations, and state missing access or unexamined sections. An abstract or metadata alone does not support a full-paper reading claim.

Lead with the answer to the user's question. Include source limits where they affect the answer, without narrating retrieval.

## Save notes only when requested

Draft notes in the conversation by default. Before saving, inspect the destination and existing content. Preserve notes and annotations; prefer a new note or agreed append over replacement. Read back the saved note and report its item/note key.

Explaining or summarizing a paper does not authorize saving a note.

For imports, metadata corrections, or duplicates, load [Zotero curation](../zotero-curation/SKILL.md). For project collections, tag meanings, or exports, load [project bibliography](../project-bibliography/SKILL.md).
