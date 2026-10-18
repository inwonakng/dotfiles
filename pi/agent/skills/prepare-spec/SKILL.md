---
name: prepare-spec
description: Use when the user asks for a standalone implementation specification, a handoff document for another agent or fresh session, or a durable specification for later implementation. Produces a self-contained spec without implementing it.
---

# Prepare spec

Write a self-contained specification that preserves intent and decisions a future implementer cannot recover from the repository.

## Boundaries

- Do not implement the change. Write a file only when requested.
- Inspect relevant code and documentation first. Resolve repository facts through inspection and ask about missing intent or decisions.
- Resolve blocking questions before finalizing.
- Mark the specification `Draft` unless the user has approved its content.
- Preserve intent without copying source code or recording incidental exploration.
- Tell the implementer to inspect current code and verify the specification's assumptions before editing.

## Content

Include the purpose and observable outcome, required behavior and acceptance criteria, relevant current behavior and repository orientation, agreed decisions, constraints and exclusions, affected contracts, implementation approach and necessary ordering, verification, and remaining assumptions or risks.

Use exact paths, symbols, commands, and expected results when they prevent guessing. Write requirements directly. Keep the document self-contained without repeating them across sections or adding a work diary.

Adapt this structure and omit empty sections:

```markdown
# [Name] specification

Status: Draft | Approved

## Purpose

## Requirements

## Current context

## Implementation approach

## Verification and acceptance

## Constraints and exclusions

## Assumptions and risks
```

After presenting or saving the specification, stop. Implementation requires an explicit request.
