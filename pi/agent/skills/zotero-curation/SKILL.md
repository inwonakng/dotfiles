---
name: zotero-curation
description: "Use when importing papers into Zotero, correcting bibliographic metadata, or reviewing duplicates and library cleanup. Verify publication sources and versions before writing. Not for read-only paper explanation or project bibliography export alone."
---

# Zotero Curation

Load [Zotero access](../zotero/SKILL.md) for reference resolution and library
identity. Read [citation sources](references/citation-sources.md) before verifying
publication status or importing/correcting publication metadata.

## Establish the change

- Identify the target library and requested items/fields. A citation, README,
  BibTeX block, or Zotero link is evidence to inspect, not permission to import or
  edit. Ask when write intent or the destination is unclear.
- Search existing items by DOI, title, and authors before importing. Inspect likely
  matches and their children, notes, annotations, collections, and tags before
  choosing reuse, correction, or a separate version.
- Use existing tags with their existing meanings. Ask before inventing a tag or
  assigning an unclear meaning. Do not add a taxonomy as part of routine import.

## Verify the citation independently

1. Treat user-supplied or repository BibTeX as a lead. Retrieve the official
   publication record independently; prefer its BibTeX/export when available
   (for example, PMLR BibTeX). Do not assume supplied citations are wrong, or that
   every official export is complete or flawless.
2. Match title, authors, DOI/identifier, venue, year, and version. Verify acceptance
   or proceedings membership separately from metadata syntax. An arXiv record or
   submitted conference page alone does not establish an accepted publication.
3. Resolve discrepancies field by field using the official record and paper.
   Preserve source URLs and distinguish accepted, published, preprint, and unknown
   status. If the official source is inaccessible or ambiguous, report the gap;
   do not fabricate venue fields or silently promote a preprint to a publication.
4. If no official record can be found after a bounded search, supplied BibTeX may
   be used as an explicitly unverified fallback within the requested import scope.
   State which fields lack independent support. An inaccessible known official
   record is a verification limitation, not proof that no official record exists.

## Import or correct

1. Check installed `zotero-cli` subcommand help before writing. Use its importer by
   default: `add bibtex` for verified official BibTeX, or an appropriate DOI/URL
   importer when that is the verified source. Do not start with hand-built API
   item JSON simply because it offers more control.
2. Confirm command-scoped library/backend settings for the write destination; the
   local SQLite prefix for native personal-library reads is not a write recipe.
   Do not switch persistent CLI defaults to solve one task.
3. Set collections, tags, and attachment behavior only within the approved scope.
   The installed importer's `--if-exists file` default can reuse an item and add
   missing collections/tags; choose deliberately, not as a read-only duplicate
   check. `--if-exists skip` leaves an existing item untouched. Collection creation
   and attachment downloads are also changes, not implicit metadata-only work.
4. Read the created/updated item back: check item type, creators, title, date,
   venue/proceedings fields, identifiers, and the requested memberships/tags.
   Compare requested fields, not just a success envelope. Preserve unrelated data;
   avoid replacing all tags when only an additive change was requested.
5. If an actual importer/edit mapping gap prevents the verified fields from being
   represented correctly, use the official Zotero API as a targeted fallback.
   Consult the [write API documentation](https://www.zotero.org/support/dev/web_api/v3/write_requests),
   use the correct library and current item version, preserve unrelated fields,
   check the response, and read back. Report the observed gap and affected fields.
   Do not bypass authorization or access restrictions to use this fallback.

## Preprints, duplicates, and cleanup

A preprint and a published record may represent versions of the same work, but
title similarity alone is not enough to merge them. Compare identifiers, authors,
content/version, and linked notes/attachments. Prefer correcting or reusing an
appropriate existing item when supported by evidence; retain separate versions
when the distinction matters or is unresolved.

Before any merge, deletion, or bulk change, present the concrete items, survivor
and field choices, and how notes, annotations, attachments, tags, and collection
memberships will be preserved. Obtain confirmation for that scope. Do not delete
a preprint or attachment merely because a publication record exists. If the
available merge path cannot preserve the user's material, stop and report it.

After authorized changes, perform basic readback of the affected records and
children. Report keys, sources, changes, and unresolved discrepancies. Do not add
a semantic tag-validation framework to this check.
