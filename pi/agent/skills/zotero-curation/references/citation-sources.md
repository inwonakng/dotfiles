# Official Citation Sources

Load this reference when verifying publication status or importing/correcting
publication metadata. These are lookup recipes, not a claim that a particular
paper has been verified. Retrieve the actual paper record and cite its URL in the
result. A source's absence or access failure is not proof of rejection.

## OpenReview: all venues

For any OpenReview-hosted paper, retrieve the official record's citation/BibTeX
export and import it with `zotero-cli add bibtex`. Do not use generic `add url`
for OpenReview records. Cross-check title, authors, year, and canonical forum URL
against the record rather than inferring them from arXiv or a repository README.
OpenReview hosting alone establishes neither the venue nor acceptance; verify the
actual venue, track, decision, and version separately.

Treat URL-only fallback imports, such as a webpage titled with the forum URL and
missing authors/year, as incomplete even if the command reports success. Report
existing stubs for scoped correction; do not automatically delete or reimport them.

## ICLR: accepted OpenReview records

Start from the relevant year at [ICLR](https://iclr.cc/) and its official
[OpenReview venue](https://openreview.net/group?id=ICLR.cc). Find the paper's
forum/record and check the venue, decision, and version for that year.

- Accepted poster, spotlight, and oral papers are all valid accepted conference
  papers. Do not restrict this workflow to years before 2024 or only oral papers.
- A submission page by itself establishes submission, not acceptance. Conversely,
  a submitted label alone is not evidence of rejection; inspect the decision or
  official accepted-paper listing. Distinguish workshops from the main conference.

## ICML: PMLR proceedings

Find the year's ICML volume through [PMLR](https://proceedings.mlr.press/) or the
conference's official proceedings link. Open the individual paper page and retrieve
its BibTeX. Prefer this official metadata over a manually reconstructed entry.
Check title, ordered authors, booktitle, year, volume, pages, editors, publisher,
and URL/DOI where supplied. Do not invent missing fields. A PMLR publication in
another venue is not evidence of ICML acceptance.

## NeurIPS: proceedings

Use the official [NeurIPS proceedings](https://proceedings.neurips.cc/), select the
year, and open the paper's abstract/record page and official citation export.
Verify the track, title, authors, year, proceedings title, and published version.
Distinguish a workshop or submission from inclusion in the claimed proceedings.
If the export and paper disagree, resolve and report that specific discrepancy;
do not assume every export is flawless.

## ACM venues: ACM Digital Library

Use the [ACM Digital Library](https://dl.acm.org/) DOI/record page and its citation
export. Match the paper to the actual conference proceedings or journal, checking
title, authors, DOI, year, publication title, pages or article number, and version.
Do not turn a proceedings article into a journal article or substitute a preprint
identifier for its publication DOI. If access blocks verification, report what is
and is not supported rather than claiming the supplied citation is false.

## Fallback and recording

An official publisher/venue record is the preferred publication source. DOI
metadata, the paper PDF, author pages, arXiv, and repository citations can help
identify or reconcile a work, but record which source supports which claim.
Keep preprint identifiers and publication identifiers distinct. A metadata export
can omit or mis-map fields; read back the imported Zotero item before declaring
the metadata corrected.

For a demonstrated Zotero CLI mapping gap, consult the official
[Zotero Web API documentation](https://www.zotero.org/support/dev/web_api/v3/start)
and [write requests reference](https://www.zotero.org/support/dev/web_api/v3/write_requests).
An API fallback changes the transport, not the approved scope or readback duty.
