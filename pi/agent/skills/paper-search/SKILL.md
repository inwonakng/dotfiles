---
name: paper-search
description: Use when searching for, filtering, or summarizing relevant academic papers. Ensures quality sources by filtering for papers with citations or reputable venues.
---

# Paper Search

Use this skill when the user asks to find, recommend, compare, or summarize academic papers for a topic.

## Core Rule

Only include a paper in the main results if at least one of these is verified:

1. **Citation gate:** the paper has **more than 10 citations** in a credible academic index such as Semantic Scholar, Google Scholar, OpenAlex, Crossref-linked metadata, DBLP-linked records, publisher pages, or another reputable scholarly database.
2. **Venue gate:** the paper is published in a **reputable peer-reviewed venue** for its field, such as a recognized conference, journal, workshop with peer review, society/publisher proceedings, or a venue whose reputation can be justified from the search context.

If neither gate can be verified, do not treat the item as evidence. Put it in an optional "excluded/unverified candidates" section only if it is useful to explain why it was not included.

## Exclusions

Do not include these in the main results:

- Random arXiv-only preprints with no verified citation count above 10 and no published version in a reputable venue.
- Blog posts, whitepapers, slide decks, newsletters, GitHub repositories, tutorials, marketing pages, or personal webpages.
- Papers where both citation count and venue reputation are unclear.
- Duplicate records when a published version exists; prefer the publisher, DOI, DBLP, Semantic Scholar, OpenReview, ACL Anthology, ACM, IEEE, USENIX, NeurIPS, PMLR, Springer, Elsevier, Wiley, Nature, Science, or society page over an arXiv page.

## Search Workflow

1. **Clarify scope if needed.** Identify the research topic, domain, date range, paper type, and whether the user wants seminal papers, recent papers, surveys, or implementation-oriented papers.
2. **Search academic sources first.** Prefer queries that target scholarly indexes and publisher/proceedings pages, for example:
   - Semantic Scholar, OpenAlex, Google Scholar snippets, Crossref, DBLP
   - ACM Digital Library, IEEE Xplore, Springer, ScienceDirect, Wiley, Nature, Science
   - ACL Anthology, PubMed, PMLR, OpenReview, USENIX, arXiv only as a pointer to a published/cited work
3. **Use web search/fetch when available.** Search targeted queries such as `site:semanticscholar.org <topic>`, `site:dblp.org <paper/topic>`, `site:aclanthology.org <topic>`, or `<topic> survey citations venue`. Fetch pages as needed to verify metadata.
4. **Verify each candidate.** Before including a paper, collect:
   - title
   - authors
   - year
   - venue or publication source
   - citation count and source, if using the citation gate
   - URL/DOI or stable academic page
   - one-sentence relevance rationale
5. **Prefer high-signal papers.** Rank by relevance first, then by evidence strength: reputable venue, citations, recency, directness to the user's question, and whether the paper is a survey or foundational work.
6. **Be honest about coverage.** Do not claim the search is exhaustive unless the search strategy actually supports that. Mention limitations such as citation counts varying by source.

## Venue Reputation Guidance

A venue can count as reputable when there is clear evidence it is peer-reviewed and recognized in the relevant field. Examples include:

- Computer science/ML: NeurIPS, ICML, ICLR, CVPR, ICCV, ECCV, ACL, EMNLP, NAACL, SIGIR, KDD, WWW/The Web Conference, CHI, UIST, CSCW, SIGCOMM, SOSP, OSDI, PLDI, POPL, ICSE, FSE, USENIX venues, ACM/IEEE transactions and conferences, PMLR proceedings.
- Biomedical/life sciences: PubMed-indexed journals, Nature/Science/Cell family journals, PLOS, JAMA, NEJM, Lancet, society journals.
- Other domains: recognized society journals/conferences, major university presses, Springer/Elsevier/Wiley/Taylor & Francis/SAGE peer-reviewed journals, and field-specific top venues.

If uncertain whether a venue is reputable, say so and rely on the citation gate instead.

## Response Format

For paper search results, prefer this structure:

1. **Search/filter criteria:** briefly state the topic and the quality gate used.
2. **Recommended papers:** table or bullets with title, year, venue, citation count/source or venue-gate evidence, URL, and relevance note.
3. **Why these:** short synthesis of themes, tradeoffs, and which papers are best starting points.
4. **Excluded/unverified candidates:** optional, only for notable items excluded because they failed the gate.
5. **Caveats:** mention if citation counts could not be checked live, if access was limited, or if the result is not exhaustive.

## Citation Count Rules

- "More than 10 citations" means **strictly greater than 10**.
- Citation counts vary by index; record the source when possible.
- If a citation count is unavailable but the venue gate is satisfied, the paper may still be included.
- If a paper has exactly 10 citations and no reputable venue, exclude it.
