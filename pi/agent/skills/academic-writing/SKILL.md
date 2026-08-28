---
name: academic-writing
description: Use when drafting, restructuring, revising, or polishing academic prose, including papers, theses, research proposals, literature reviews, abstracts, and responses to reviewers. Requires an outline or reverse outline before prose work, preserves evidentiary limits, and rewrites passages where empty abstractions or undefined conceptual shorthand substitute for concrete claims. Do not use for paper discovery alone, citation formatting alone, or non-academic writing.
---

# Academic Writing

Produce academic prose that is clear, elegant, precise, and readable without making it ornate or artificially technical.

## Core Rules

1. **Outline before prose.** For new substantive writing, the first response contains only the outline and a request for approval. Never draft in the same response that introduces or materially changes the outline. Draft only after the user approves it.
2. **Write for the reader.** Match the vocabulary, assumed knowledge, detail, and conventions to the audience and venue.
3. **Make the argument visible.** State claims precisely, support them with available evidence, and explain how the evidence bears on each claim.
4. **Respect evidentiary limits.** Never invent citations, quotations, facts, data, results, methods, source positions, mechanisms, limitations, or implications. This applies to outlines as well as prose. Every factual claim must trace to the user's material or a verified source; mark missing support instead of filling it in.
5. **Rewrite empty statements.** Treat undefined conceptual shorthand as evidence that a passage may lack a concrete claim. Return to the outline and rewrite the affected passage from its intended claim and support instead of repairing the phrase.

## Workflow

### 1. Establish the Writing Context

Determine from the request and available material:

- genre and scope
- intended audience and its expected background
- venue or disciplinary conventions, when relevant
- purpose, thesis, research question, or central claim
- evidence, sources, and technical terms that must be used
- desired voice and constraints

Ask only for information that blocks a responsible outline. Do not repeat questions that the context already answers.

### 2. Outline at the Scale of the Task

Before producing prose, present one of these. Build it only from supplied or verified claims. Mark an unsupported background statement, research gap, or motivation as `[evidence needed]` rather than presenting it as fact:

- **Paper, chapter, or proposal:** a section outline giving each section's purpose, principal claims, supporting evidence, and relation to adjacent sections.
- **Section:** a paragraph outline giving each paragraph's function, claim, evidence, and transition.
- **Paragraph, abstract, or short response:** a compact outline of the intended claim sequence and the function of each sentence or sentence group.
- **Revision of existing prose:** a reverse outline stating what each section or paragraph currently does, followed by the proposed structural changes.
- **Narrow sentence-level correction:** a one-line statement of the meaning to preserve and the intended edit.

A user-supplied outline counts only when the user explicitly identifies it as an outline and it states the intended claims and their order. A thesis, evidence, notes, or drafting instructions are inputs to an outline, not an approved outline by themselves. A request to draft from an explicitly supplied outline counts as approval. If that outline has a consequential gap, point out the gap and propose a revision before drafting.

Present the outline separately from the prose. For new substantive prose or a substantive rewrite, outlining and drafting must occur in separate turns. Apply this stage gate:

- If you created or materially changed the outline in the current response, end that response after asking the user to approve or revise it. Do not include any of the requested prose.
- Draft only when the outline existed before the current response and the user has approved it. A request to "draft it now" does not approve an outline the user has not yet seen.
- Before sending a response that introduces an outline, remove any draft prose that follows the approval question.

A narrow correction may follow its one-line outline in the same response when the edit preserves meaning. If the user asks to skip outlining, provide the smallest useful outline rather than silently bypassing it.

### 3. Draft from the Approved Outline

For each unit of prose:

- give it one clear function in the argument;
- make the principal claim easy to locate;
- distinguish evidence, interpretation, and speculation;
- explain why cited evidence supports the claim rather than merely placing them together;
- connect adjacent ideas through their actual logical relationship;
- make every factual and methodological statement traceable to the approved outline, user material, or a verified source;
- preserve the approved scope and do not add plausible-sounding mechanisms, reasons, limitations, implications, application settings, or future work that the material does not support.

Use headings and transitions to clarify structure, not to compensate for an unclear argument.

### 4. Revise in Separate Passes

Review the draft in this order:

1. **Structure:** Does the prose follow the approved outline and fulfill its stated purpose?
2. **Argument:** Are claims precise, supported, and connected to the evidence?
3. **Paragraphs:** Does each paragraph perform one identifiable job and connect to its neighbors?
4. **Style:** Is the prose direct, readable, and appropriately formal?
5. **Voice and emphasis:** Does each action have an appropriate visible actor? Express authorial choices with `we` and an active verb. Rewrite instrumental passives, and retain a corrective contrast only when it rejects a specific interpretation or alternative present in the argument.
6. **Empty statements:** Does every substantive sentence make a concrete claim, or has shorthand taken the place of thought?
7. **Terminology:** Are specialized terms necessary, consistent, and defined for the audience?
8. **Integrity:** Did the draft introduce any unsupported fact, citation, quotation, result, or causal explanation?

Revise substantive problems before polishing individual sentences.

## Prose Standard

Elegant academic prose makes difficult ideas easier to understand while keeping attention on the argument.

- Prefer precise, familiar words when they express the same meaning as a more elaborate alternative.
- Prefer concrete subjects and strong verbs to strings of abstract nouns.
- Give a sentence one principal job, but vary sentence length and structure naturally.
- Remove filler, repetition, hollow emphasis, and transitions that do not express a real relationship.
- Use technical terminology when it improves precision; explain it when the audience may not know it.
- Calibrate confidence: report observed results directly, distinguish association from causation, and label hypotheses or interpretations as such.
- Preserve the author's meaning and individual voice when revising. If the source is ambiguous, flag the ambiguity rather than silently choosing a meaning.

### Active Voice and Direct Claims

Use active voice as the default and make the actor explicit.

- Express choices and actions made by the authors with `we` and a concrete verb: `We use the encoder to produce sentence representations.` Preserve another authorial convention only when the user or venue requires it.
- Use a method, system, or component as the subject when it performs the action: `The encoder produces sentence representations.`. You may also mix in `We implement the encoder to produce sentence representations.` when highlighting the choices made by the authors if appropriate.
- Use passive voice deliberately when the actor is unknown or irrelevant, or when continuity requires the acted-upon object to remain the subject. Otherwise, replace instrumental passives such as `The encoder is used to produce sentence representations` with an active construction.

State the substantive claim directly in affirmative form. Reserve corrective contrasts such as `not X but Y`, `not merely X`, `does not simply X`, and `rather than X` for passages that address `X` as a specific interpretation, expectation, or documented alternative. If the claim in `Y` stands on its own, omit the rhetorical setup and state `Y` directly:

- Mechanical: `Our method does not merely aggregate features; it models their relationships.`
- Direct: `Our method models relationships among features.`

Every retained contrast must express a relationship that matters to the argument, rather than serving only as emphasis.

## Empty Statements and Conceptual Shorthand

An empty statement sounds substantive but does not make a concrete, supportable claim. Conceptual shorthand is a common sign of this failure: a compact phrase is presented as a concept, property, mechanism, category, or relationship without doing precise work in the argument.

Warning patterns include:

- ad hoc compounds such as `evidence-aware`, `reader-first`, or `claim-driven`;
- abstract properties with no criterion, such as `conceptual robustness`, `structural fidelity`, or `interpretive stability`;
- unnamed objects or mechanisms such as `reasoning layer`, `semantic signal`, or `knowledge boundary`;
- compressed relationships such as `method-task alignment` or `representation-reasoning interface`;
- evaluative claims such as “provides deeper insight” or “offers a more coherent account” when the prose does not state what was learned or made coherent.

These are warning patterns, not banned strings. Established technical terms and terms explicitly defined by the paper are acceptable when they express a precise idea that the argument needs.

When a warning pattern appears, do not preserve it, embellish it, replace it with a synonym, or expand it into a longer abstraction. Treat it as a drafting failure:

1. Return to the approved outline and identify the passage's intended function.
2. Recover the concrete claim and the evidence or reasoning that supports it.
3. Discard the empty sentence or passage and rewrite it from that claim and support, not from its original wording.
4. If the available material does not support a concrete statement, remove it or mark the missing claim or evidence.
5. If empty statements recur throughout a section, rewrite the section from its outline instead of repairing sentences individually.

During the final pass, check every phrase introduced by the agent that appears to name a concept or property. If the phrase cannot be tied to a concrete claim and support, redo the affected passage. Do not ask the user to define language that the agent introduced.

## Source and Citation Discipline

- Use only sources provided by the user or verified through an appropriate research workflow.
- Do not infer a source's position from its title, abstract fragment, or reputation alone.
- Preserve citation keys, quotations, equations, labels, and technical notation unless the user asks to change them and the change can be verified.
- Use an explicit placeholder such as `[citation needed]`, `[evidence needed]`, or `[verify wording against source]` when support is missing.
- When the task requires finding or evaluating papers, use the `paper-search` skill before relying on them in prose.

## Boundaries

Do not use this skill for paper discovery or literature search alone, citation-style lookup alone, LaTeX compilation or layout work, implementation planning, or non-academic prose. Use it after research when the task turns to structuring or writing an academic document.
