---
name: project-bibliography
description: "Use when organizing a project's Zotero collections or subcollections, interpreting its existing tags, or exporting and maintaining a project bibliography. Not for general paper search, a single-paper explanation, or metadata cleanup without a project bibliography task."
---

# Project bibliography

Load [Zotero access](../zotero/SKILL.md) for library and reference resolution. Load [Zotero curation](../zotero-curation/SKILL.md) when importing papers or correcting metadata.

## Establish scope

Read the project's `AGENTS.md` and bibliography/export setup. Inspect the collection hierarchy and relevant items before choosing a library, collection, tags, or output file.

Resolve names and paths to keys in the intended library. Matching names under different libraries or parents are not interchangeable. A reference scopes reading; it does not authorize reorganization or overwriting an export.

Determine:

- library identity and project collection key/path
- collection-only or recursive scope
- membership: all scoped items, cited works, or an existing selection/filter
- established export path, format, and citation-key policy

Ask about missing choices that affect the task. Keep direct native collection reads nonrecursive unless the user or project convention requests descendants.

## Use existing collections and tags

Reuse collections that fit the agreed organization. Create or move them only when requested, after verifying library and parent. Preserve other memberships; adding an item to this project does not authorize removing it elsewhere or deleting it.

Inspect exact tag names, their use on relevant items, and documented meanings. Ask before inventing tags or interpreting ambiguous ones. Do not infer meaning from spelling, impose prefixes or a taxonomy, or introduce a global schema. Native tag references require exact equality as described in Zotero access.

Confirm concrete scope before merges, deletions, or bulk tag/collection changes. After authorized writes, read back affected items or memberships. Basic checks are sufficient; do not build a semantic validation layer.

## Export the agreed set

1. Resolve membership before export. For recursive scope, enumerate descendants and their items explicitly; do not assume `export --collection` includes them. Fetch all needed pages, deduplicate by library/item identity, and exclude notes and attachments. State incomplete enumeration.
2. Inspect installed `zotero-cli export --help` and use its supported collection or explicit-item export. Retain the project's Better BibTeX or other exporter/key mechanism. Inspect suspicious metadata and use curation guidance for corrections.
3. Export to a temporary file outside the repository. Compare entries with the selected set, checking omissions, key collisions, and the existing key policy. Before proposing key changes, identify affected in-project citations; never rename keys silently.
4. Write the agreed path only with authorization. Preserve unrelated entries and ask before replacing mixed/manual content. Read back the file.

Report the exported item scope, output path, key changes, exclusions, and unresolved metadata without repeating the export procedure.

## Record conventions only when requested

Add a short prose section to the project's `AGENTS.md` with the agreed library identity, collection key/path, recursive scope, membership rule, export path/format, and key policy. Include existing tag meanings only when known and relevant.

Do not invent project values, create a global configuration schema, or edit instructions for a one-off export.
