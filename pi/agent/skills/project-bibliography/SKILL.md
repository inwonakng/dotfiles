---
name: project-bibliography
description: "Use when finding related work for a project, adding papers to its Zotero collection, grounding project discussion in existing references, synthesizing prior work, reviewing collection relevance or tags, or explicitly exporting its bibliography. Not for unrelated paper searches, standalone paper explanations, routine coding or brainstorming, or metadata-only cleanup."
---

# Project literature workflow

Use the project's research question to decide which papers to find, keep, and consult. Discovery, collection, discussion, synthesis, and review are separate activities; do not automatically run them as a pipeline.

## Establish project context

Read the project's `AGENTS.md` and any linked research-scope document. Use its research questions, inclusion/exclusion criteria, library identity, collection key/path, and established tag meanings. Ask only about missing choices that affect the current task; a web search does not require setting up a Zotero collection.

Load [Zotero access](../zotero/SKILL.md) before library reads. Resolve the intended library and collection by key, not name alone. Keep collection reads nonrecursive unless the user or project convention includes descendants. Inspect relevant items rather than enumerating the whole collection by default.

When asked to record project conventions, put the agreed scope, collection identity, and tag meanings in the project's `AGENTS.md` or a linked document. Do not invent project values or update instructions during ordinary literature work.

## Discover related work

Trigger: the user asks to find papers, update related work with additional literature, find external evidence, or assess novelty. Revising a related-work section from existing references belongs to consultation and synthesis, not automatic discovery.

1. Identify the specific question or gap the search should address. Use relevant existing references as seeds when available; do not reread the whole collection first.
2. Load [paper search](../paper-search/SKILL.md) for searching and source-quality checks. Combine targeted searches with backward references and forward citations from useful seed papers.
3. Present a focused shortlist with source links and each paper's concrete role in the project: comparison, method, dataset, evidence, or necessary background. Include relevant conflicting evidence, not only papers supporting the project's approach.
4. Distinguish new candidates from known references when checked. State search and access limits; absence from the project collection does not establish novelty.

Search results are proposals, not permission to import, tag, or save notes. Ask which candidates the user wants to keep unless they already authorized specific additions.

## Collect with confirmed tags

Trigger: the user asks to add papers or approves candidates for the project.

1. Check the intended library for existing records before import. Reuse an appropriate record and add project membership rather than duplicating it. Load [Zotero curation](../zotero-curation/SKILL.md) for identity/version checks, imports, and metadata corrections.
2. Explain why each proposed addition belongs in this project. Broad topical similarity alone is not enough; distinguish papers awaiting relevance assessment from selected related work using the project's agreed convention.
3. Every paper in the project collection should have at least one sensible, user-confirmed tag describing its topics or paper type. Follow [Zotero curation](../zotero-curation/SKILL.md) to inspect the library's existing tags, reuse suitable terms, and propose new tags when needed. Collection membership already identifies the project; do not duplicate it with a project-name tag.
4. Propose the exact tags to retain or add for each paper and ask the user to confirm them before importing or changing project membership or tags. Batch confirmation is fine. If the user already specified the papers, destination, and tags, do not ask again. Imported keywords are not automatically suitable tags.
5. Apply only the approved imports, memberships, and tags. Preserve unrelated tags, memberships, notes, and attachments. Read back the affected records to confirm project membership and agreed tags, and report any incomplete additions.

For blocked imports, follow [When automated import is blocked](../zotero-curation/SKILL.md#when-automated-import-is-blocked) to request manual addition and verify the synced item before continuing. Manual addition does not replace the agent's responsibility to propose suitable tags and obtain any outstanding tag approval.

Do not turn one addition into a library-wide retagging exercise. Flag existing untagged papers encountered during review and propose tags for approval.

## Consult existing references

Trigger: the user asks what collected papers say, compares the project with prior work, or asks a question whose answer depends on evidence from those papers.

- Retrieve the subset relevant to the question. Start with metadata and existing notes, then read the passages needed to support the answer. A single-paper explanation normally needs only Zotero access, not a collection scan.
- Cite the papers and relevant passages actually consulted. Separate the papers' findings, the user's notes, and your own interpretation; metadata or an abstract does not establish a full-paper reading.
- If the collection cannot answer the question, say what is missing. Offer a targeted external search rather than silently expanding ordinary discussion into discovery. An explicit search or novelty-assessment request already triggers discovery.
- Do not consult Zotero merely because a conversation takes place in the project. Routine coding, general explanation, and brainstorming need no literature lookup unless the question calls for it.

Reserve collection-wide inspection for collection-wide questions. Inspecting an inventory does not require reading every paper.

## Synthesize around the question

Trigger: the user asks how the project fits prior work, requests a comparison across papers, or wants help drafting related work.

Organize the answer around relevant assumptions, methods, findings, limitations, and consequences for the project. Identify agreement, disagreement, and missing evidence rather than concatenating paper summaries. Distinguish gaps in this collection from demonstrated gaps in the literature.

Use a small comparison table when it helps. Keep synthesis in the conversation unless the user asks to save it; do not require a spreadsheet, notes database, or export as part of discussion.

## Review relevance and coverage

Trigger: the user requests a collection review or the project's research scope changes. After an addition batch, check the added papers' relevance, overlap, membership, and tags; do not audit the entire collection after every change.

For a broader review, inspect the agreed collection scope and identify unclear relevance, unresolved candidates, missing or ambiguous tags, and missing coverage. Explain what each proposed removal no longer contributes. Being old, uncited, or contrary to the project's hypothesis is not by itself a reason to drop a paper.

Present proposed changes for confirmation. Before removing membership, check whether the project still cites or depends on the paper. Confirm concrete scope before merges, removals, or bulk tag/collection changes, and read back authorized changes. Removing a paper from this project is not deleting it from Zotero or removing it from other collections. Create or move collections only when requested, after verifying the library and parent.
