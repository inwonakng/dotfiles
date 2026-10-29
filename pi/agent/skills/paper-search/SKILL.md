---
name: paper-search
description: >-
  Use when searching for, filtering, or summarizing relevant academic papers. Ensures quality sources by filtering for papers with citations or reputable venues.
---

# Paper search

Include a paper in the main results only after verifying either:

- More than 10 citations in a credible academic index, such as Semantic Scholar, Google Scholar, OpenAlex, Crossref-linked metadata, DBLP-linked records, or a reputable publisher or scholarly database.
- Publication in a reputable peer-reviewed venue for its field.

Exactly 10 citations does not meet the citation threshold. A verified venue is sufficient when citation counts are unavailable. Record the citation source; counts vary by index.

## Exclude unsupported candidates

Exclude papers with neither gate verified, arXiv-only preprints without enough verified citations, and non-paper sources such as blogs, whitepapers, slides, newsletters, repositories, tutorials, marketing pages, and personal pages.

Prefer the published record over duplicate preprint entries. Use publisher, DOI, DBLP, Semantic Scholar, OpenReview, ACL Anthology, ACM, IEEE, USENIX, NeurIPS, PMLR, or other official scholarly pages when available.

Mention an excluded or unverified candidate only when its exclusion matters to the answer. Do not use it as evidence.

## Search and verify

1. Establish the topic, domain, date range, and requested paper type: foundational work, recent research, surveys, or implementation-oriented papers. Ask only when scope is unclear.
2. Search academic indexes and publisher/proceedings pages first. Useful sources include Semantic Scholar, OpenAlex, Google Scholar, Crossref, DBLP, ACM, IEEE, Springer, ScienceDirect, Wiley, Nature, Science, ACL Anthology, PubMed, PMLR, OpenReview, and USENIX. Use arXiv as a pointer to a qualifying work.
3. Use targeted web queries, such as `site:semanticscholar.org <topic>`, `site:dblp.org <paper/topic>`, or `site:aclanthology.org <topic>`. Fetch pages to verify metadata.
4. Collect title, authors, year, venue or publication source, stable URL/DOI, relevance, and citation count/source when using that gate.
5. Rank by relevance first, then venue and citation evidence, recency, directness to the question, and value as a survey or foundational work.
6. State access limits and coverage honestly. Claim exhaustiveness only when the search strategy supports it.

## Verify the venue

Require evidence of peer review and recognition in the relevant field. Examples include:

- CS/ML: NeurIPS, ICML, ICLR, CVPR, ICCV, ECCV, ACL, EMNLP, NAACL, SIGIR, KDD, The Web Conference, CHI, UIST, CSCW, SIGCOMM, SOSP, OSDI, PLDI, POPL, ICSE, FSE, USENIX, ACM/IEEE conferences and transactions, and PMLR proceedings.
- Biomedical/life sciences: PubMed-indexed journals, Nature/Science/Cell journals, PLOS, JAMA, NEJM, Lancet, and society journals.
- Other fields: recognized society venues, major university presses, and relevant peer-reviewed Springer, Elsevier, Wiley, Taylor & Francis, or SAGE journals.

Verify acceptance separately from submission. An OpenReview page labeled "Submitted to ICLR" does not establish acceptance; look for an accepted track or decision, such as ICLR Poster or Spotlight.

Prefer final citations from official sources: [NeurIPS](https://nips.cc), [ACL Anthology](https://aclanthology.org), [ICLR](https://iclr.cc), [ICLR OpenReview](https://openreview.net/group?id=ICLR.cc), [ICML](https://icml.cc), or [ACM](https://dl.acm.org). If venue reputation is uncertain, say so and use the citation gate instead.

## Present results

Lead with recommended papers in bullets or a table. Include title, year, venue, qualifying evidence, URL, and a concise relevance note. Name the best starting point when useful.

Keep the search scope and quality criteria brief. Add synthesis only when it helps compare papers; do not repeat each relevance note. Include excluded candidates or caveats only when they affect interpretation, including unavailable live citation counts, access limits, or incomplete coverage.
