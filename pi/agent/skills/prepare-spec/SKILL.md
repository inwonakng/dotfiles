---
name: prepare-spec
description: Use when the user asks for a standalone implementation specification, a handoff document for another agent or fresh session, or a durable specification for later implementation. Produces a self-contained spec without implementing it.
---

# Prepare Spec

Use this skill when implementation will happen outside the current conversation. The specification must preserve the intent and decisions that the next agent cannot recover from the repository alone.

## Rules

- Do not implement the change.
- Write a file only when the user asks for one.
- Inspect the relevant code and documentation before writing the specification.
- Resolve repository facts through inspection. Ask the user about missing intent or decisions that cannot be discovered.
- Do not finalize a specification with unresolved blocking questions.
- Mark it `Draft` unless the user has already approved its content.
- Keep it self-contained, but do not copy source code or include incidental exploration details.
- Treat the specification as the source of truth for intent. Tell the implementing agent to inspect the current code and verify the specification's assumptions before editing.

## Required Content

A specification should state:

- the purpose and observable outcome
- required behavior and acceptance criteria
- relevant current behavior and repository orientation
- agreed decisions, constraints, and exclusions
- affected contracts or interfaces
- the implementation approach and order, where order matters
- verification that demonstrates the outcome
- assumptions, risks, and any remaining non-blocking uncertainty

Include exact paths, symbols, commands, or expected results only when they help the next agent act without guessing.

## Spec Shape

```markdown
# [Name] Specification

**Status:** Draft | Approved

## Purpose

## Requirements

## Current context

## Implementation approach

## Verification and acceptance

## Constraints and exclusions

## Assumptions and risks
```

Adapt the shape to the task and omit empty sections. Keep the document clear enough for a fresh agent, but no longer than needed.

After presenting or saving the specification, stop. Do not begin implementation without an explicit request.
