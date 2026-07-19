---
name: plan
description: Use when the user asks to plan, design, or compare implementation approaches, or when an unresolved design decision blocks implementation. Produces a standalone plan for user approval without modifying code.
---

# Implementation Planning

Use this skill to turn a request into a clear, approved implementation plan before code is changed.

The main agent owns implementation planning because it has the user conversation, intent, constraints, and approval loop. A `planner` subagent may research a named subsystem, critique the draft, or recommend task boundaries. Its output becomes part of the plan only after main-agent synthesis and any required user approval.

## Rules

- Do not modify files while using this skill unless the user explicitly asks you to write a plan file.
- Do not silently continue into implementation. Stop after the plan and wait for explicit implementation approval.
- During exploratory planning, ask the single question whose answer would most change the design. During final plan review, batch independent blocking questions so the user can resolve them together.
- When writing an implementation plan file, include the Agent Handoff marker below. This is mandatory unless the user explicitly asks for a scratch note or non-implementation document.
- If the plan is more than a few steps, break it up into separate steps. Name the plan files with the order prefix (e.g., `plans/{this-plan}/01-setup.md`, `plans/{this-plan}/02-feature.md`) so they can be executed in order. Each plan should be reviewable and verifiable on its own. If the plan is a single step, name it `plans/{this-plan}.md`, where `{this-plan}` is a descriptive name of the main plan.

## Process

1. **Understand intent**
   - Restate the goal in concrete terms.
   - Identify success criteria, constraints, and what is out of scope.
   - Identify behavior and contracts that must remain unchanged.
   - Identify affected users, callers, data, interfaces, and failure paths.
   - If the request is too large, propose a first slice only when it is independently useful, verifiable, and compatible with the intended end state. State what the slice does not complete.

2. **Inspect targeted context**
   - Read the files and documentation needed to explain the current behavior, affected contracts, likely failure modes, and verification path.
   - Follow existing project patterns before proposing new structure.
   - Use `spawn` with `agent: "researcher"` or `agent: "planner"` and `accessMode: "readonly"` when a named subsystem needs separate investigation or a fresh critique. Join background spawns before relying on their results.

3. **Explore approaches**
   - Present alternatives only when they differ in behavior, architecture, migration cost, or operational risk.
   - Include concrete tradeoffs and a recommendation.
   - Skip fake alternatives when project constraints determine the approach.

4. **Produce the plan**
   - Break work into steps that each produce an observable, verifiable result.
   - Name exact files or modules where known.
   - State which requirement and affected contract each step covers.
   - Include verification commands or checks.
   - Separate assumptions, risks, and open questions.
   - For complex work, ask whether to save the plan under `plans/` before implementation.
   - If saving an implementation plan file, include status, source-of-truth notes, and the Agent Handoff marker so a later implementation agent knows to use `subagent-driven-implementation`.

5. **Stop**
   - Ask the user to approve or revise the plan.
   - Do not edit code until the user explicitly asks to implement/fix/apply/build/refactor.

## Plan Shape

Use this shape unless the task calls for something shorter:

```markdown
# [Name] Implementation Plan

> <**Agent Handoff Marker**>

**Status:** Draft | Approved
**Source of truth:** [conversation summary, issue, spec, or design doc]

## Goal

## Recommended approach

## Steps
1. ...
2. ...

## Verification

## Assumptions

## Risks

## Open questions
```

## Agent Handoff Marker

When writing a durable implementation plan file, include this marker verbatim near the top:

```markdown
> **Agent handoff:** When asked to implement this plan, use the `subagent-driven-implementation` skill. Start with a readonly planner or reviewer to identify blocking questions before editing. Use write subagents only for tasks with exact, non-overlapping file scope. Execute tasks in order unless this plan explicitly marks tasks independent.
```

If the plan is not approved yet, mark `**Status:** Draft`. Do not imply approval. If the user approves the plan, update or state the approved status clearly before implementation.

## Quality Bar

A good plan lets another agent trace every requirement to an implementation step and a verification check without re-deciding the design. It does not invent code that the inspected files do not support.
