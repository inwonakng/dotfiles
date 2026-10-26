---
name: zotero-curation
description: "Use when importing papers into Zotero, correcting bibliographic metadata, or reviewing duplicates and library cleanup. Verify publication sources and versions before writing. Not for read-only paper explanation or project bibliography export alone."
---

# Zotero curation

Load [Zotero access](../zotero/SKILL.md) for reference resolution and library identity. Read [citation sources](references/citation-sources.md) before verifying publication status or importing/correcting publication metadata.

## Establish the change

Identify the target library and requested items or fields. Citations, README files, BibTeX, and Zotero links are evidence to inspect, not permission to write. Ask if write intent or destination is unclear.

Before import, search by DOI, title, and authors. Inspect likely matches and their children, notes, annotations, collections, and tags before choosing reuse, correction, or a separate version.

Reuse tags with established meanings. Ask before inventing tags or assigning unclear meanings; routine import does not need a taxonomy.

## Verify the citation

1. Treat supplied or repository BibTeX as a lead. Retrieve the official record independently and prefer its export, such as PMLR BibTeX. Neither supplied citations nor official exports are automatically correct or complete.
2. Match title, authors, DOI/identifier, venue, year, and version. Verify acceptance or proceedings membership separately from syntax. arXiv records and submission pages alone do not establish accepted publication.
3. Resolve discrepancies field by field against the official record and paper. Retain source URLs and distinguish accepted, published, preprint, and unknown status. Report inaccessible or ambiguous sources; never invent venue fields or promote a preprint silently.
4. After a bounded search finds no official record, supplied BibTeX may be an explicitly unverified fallback within the requested import scope. State unsupported fields. An inaccessible known record is a verification limit, not evidence that no record exists.

## Import or correct

1. Check installed `zotero-cli` subcommand help. Prefer its importer: `add bibtex` for verified official BibTeX, or the appropriate DOI/URL importer for that verified source. Do not start with hand-built API item JSON for extra control.
2. Confirm command-scoped library/backend settings for the destination. The SQLite prefix for native personal-library reads is not a write recipe. Do not change persistent CLI defaults for one task.
3. Keep collections, tags, and attachment behavior within scope. The importer's `--if-exists file` default can reuse an item and add missing collections/tags; it is not a readonly duplicate check. `--if-exists skip` leaves existing items untouched.
4. Every imported paper must have a PDF attached. Do not consider the import complete until the attachment is verified. If the importer skips the PDF, retrieve and attach it separately. If a PDF cannot be obtained, report the paper as incomplete and let the user know.
5. Read back the item and compare requested fields: type, creators, title, date, venue/proceedings, identifiers, memberships, and tags. A success envelope is insufficient. Preserve unrelated data, including existing tags when the change is additive. After final metadata changes, also read back native `citationKey` and any legacy `Citation Key` in Extra. Flag URL-derived (including sanitized URLs), placeholder, or conflicting keys as unresolved. Preserve established citation-key conventions; do not impose a uniform format or silently rename existing keys that may already be cited.
6. Use the official Zotero API only for an observed importer/edit mapping gap. Consult the [write API documentation](https://www.zotero.org/support/dev/web_api/v3/write_requests), use the correct library and current item version, preserve unrelated fields, check the response, and read back. Report the gap and affected fields. This fallback does not bypass authorization or access restrictions.

## Handle versions and cleanup

Compare identifiers, authors, content/version, and linked notes/attachments before treating a preprint and publication as the same work. Title similarity is insufficient. Correct or reuse an appropriate item when supported; retain separate versions when the distinction matters or is unresolved.

Before merges, deletions, or bulk changes, present the concrete items, survivor and field choices, and preservation of notes, annotations, attachments, tags, and memberships. Obtain confirmation for that scope. Do not delete a preprint or attachment merely because a publication exists. Stop if the merge path cannot preserve the user's material.

After authorized changes, read back affected records and children. Report keys, sources, changes, and unresolved discrepancies concisely. Basic readback is sufficient; do not add semantic tag validation.

## Assign Tags

Tags describe the topics covered in a paper or its type, such as a survey, benchmark paper, or dataset paper. Collections represent project membership; do not add tags that merely repeat that membership.

Before proposing or assigning tags, inspect the existing tag set in the
target library, not just the tags on the selected papers. Reuse existing tags when their meanings fit the paper. If the tag inventory is unavailable or incomplete, state that limitation rather than assuming a tag is new.

Use self-explanatory names. Prefer full terms unless an abbreviation is widely accepted in the relevant field. Do not create synonyms or abbreviated variants of existing tags, or rename existing tags without approval.

If existing tags do not adequately describe the paper's topics or type,
propose the exact new names, explain what they describe and why existing
tags are insufficient, and ask the user before creating or applying them.
Batch confirmation is fine. Do not ask again for tags already explicitly
approved for the requested papers.

Preserve unrelated existing tags. Tag selection does not authorize
library-wide renaming or cleanup.
