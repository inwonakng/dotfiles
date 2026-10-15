---
name: project-bibliography
description: "Use when organizing a project's Zotero collections or subcollections, interpreting its existing tags, or exporting and maintaining a project bibliography. Not for general paper search, a single-paper explanation, or metadata cleanup without a project bibliography task."
---

# Project Bibliography

Load [Zotero access](../zotero/SKILL.md) for library and reference resolution.
If the task also imports papers or corrects metadata, load
[Zotero curation](../zotero-curation/SKILL.md) for source verification and writes.

## Establish project scope

Read the project's `AGENTS.md` and existing bibliography/export setup before
choosing a library, collection, tags, or output file. Inspect the actual collection
hierarchy and a few relevant items. Resolve names/paths to keys in the intended
library; matching names in different libraries or under different parents are not
interchangeable. A collection reference scopes a read; it does not authorize
reorganization or exporting over a project file.

Determine:

- library identity and the project collection key/path;
- whether scope is the collection alone or includes subcollections recursively;
- bibliography membership: all scoped items, only cited works, or an existing
  explicit selection/filter;
- export path/format and citation-key policy already used by the project.

Ask about missing choices that affect the task rather than imposing defaults.
For a direct native collection reference, retain nonrecursive reading unless the
user or established project convention requests subcollections.

## Collections and existing tags

Use collections/subcollections for the project's agreed organization. Reuse an
existing collection where it matches; create or move collections only when
requested. Verify parent and library before writing, and preserve other collection
memberships. Adding a paper to a project collection is not permission to remove it
from other projects or delete the library item.

Inspect exact tag names and their use on relevant items, plus any documented
meanings. Reuse that system: tags may encode topics, reading status, or something
else, but do not assume meanings from spelling alone. Ask before inventing tags or
using ambiguous ones. Do not impose prefixes, a taxonomy, or a global tag schema.
Native tag references still require exact equality as described in Zotero access.
A basic post-write check of requested tags/memberships is sufficient; do not build
a semantic validation layer.

Confirm concrete scope before merges, deletes, or bulk tag/collection changes.
Read back affected items or collection membership after authorized changes.

## Export the intended bibliography

1. Resolve membership before export. For recursive scope, enumerate descendants
   and collect their items explicitly; do not assume `export --collection` includes
   descendants. Fetch all needed result pages, deduplicate by library/item identity,
   and exclude notes/attachments from bibliography membership. State any incomplete
   enumeration rather than claiming a complete export.
2. Check installed `zotero-cli export --help`. Use its supported collection or
   explicit-item export for the agreed set. If the project uses Better BibTeX or
   another existing exporter/key mechanism, retain that workflow rather than
   silently replacing it. Inspect metadata of suspicious entries; use curation
   guidance for corrections instead of laundering uncertain citations into BibTeX.
3. Export to a temporary file outside the repository first. Inspect the resulting
   entries against the selected item set and check missing entries, key collisions,
   and the established citation-key policy. Do not rename existing citation keys
   silently; identify affected in-project citations before proposing key changes.
4. Write the agreed project path only with authorization. Preserve unrelated
   entries if the file is not owned entirely by this export; ask before replacing
   mixed/manual content. Read back the written file and report the item scope,
   output path, key changes, and any exclusions or unresolved metadata.

## Record conventions lightly

When the user requests persistent project conventions, add a small prose section
in that project's `AGENTS.md`, not a new global schema or configuration format.
Record the agreed library identity, collection key/path, recursive scope,
bibliography membership rule, export path/format, and citation-key policy. Include
existing tag meanings only when known and relevant. Do not invent project values
or edit instructions merely because the user asked for a one-off export.
