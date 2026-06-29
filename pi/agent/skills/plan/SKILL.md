---
name: plan
description: Use before implementing non-trivial code changes, when the user asks to plan/design/think through an approach, or when requirements are ambiguous. Produces a standalone implementation plan that can be executed by subagents without modifying files.
---

# Implementation Planning

Use this skill to turn a request into a clear, approved implementation plan before code is changed.

The main agent owns implementation planning because it has the user conversation, intent, constraints, and approval loop. A `planner` subagent is only an advisory helper for bounded research, critique, or execution-slice recommendations; do not let a subagent's plan become the source of truth without main-agent synthesis and user approval when approval is required.

## Rules

- Do not modify files while using this skill unless the user explicitly asks you to write a plan file.
- Do not silently continue into implementation. Stop after the plan and wait for explicit implementation approval.
- If relevant information is missing, ask one focused clarifying question at a time.
- When writing an implementation plan file, include the Agent Handoff marker below. This is mandatory unless the user explicitly asks for a scratch note or non-implementation document.
- If the plan is more than a few steps, break it up into separate steps. Name the plan files with the order prefix (e.g., `plans/{this-plan}/01-setup.md`, `plans/{this-plan}/02-feature.md`) so they can be executed in order. Each plan should be reviewable and verifiable on its own. If the plan is a single step, name it `plans/{this-plan}.md`, where `{this-plan}` is a descriptive name of the main plan.

## Process

1. **Understand intent**
   - Restate the goal in concrete terms.
   - Identify constraints, success criteria, and what is out of scope.
   - If the request is too large, propose a smaller first slice.

2. **Inspect targeted context**
   - Read only the files/docs needed to make the plan reliable.
   - Follow existing project patterns before proposing new structure.
   - Use `defer_task` with `agent: "researcher"` or `agent: "planner"` and `accessMode: "readonly"` for bounded independent research or plan critique when isolated context would help.

3. **Explore approaches**
   - Present 2-3 plausible approaches when there is a meaningful design choice.
   - Include tradeoffs and a recommendation.
   - Skip fake alternatives when the right path is obvious from project constraints.

4. **Produce the plan**
   - Break work into reviewable steps.
   - Name exact files/modules where known.
   - Include verification commands or checks.
   - Include risks, open questions, and assumptions.
   - For complex work, ask whether to save the plan under `plans/` before implementation.
   - If saving an implementation plan file, include status, source-of-truth notes, and the Agent Handoff marker so a later implementation agent knows to use `subagent-driven-implementation`.

5. **Stop**
   - Ask the user to approve or revise the plan.
   - Do not edit code until the user explicitly asks to implement/fix/apply/build/refactor.

## Plan Shape

Use this shape unless the task calls for something shorter:

```markdown
# [Name] Implementation Plan

> **Agent handoff:** When asked to implement this plan, use the `subagent-driven-implementation` skill. Start with a readonly planner or reviewer subagent plan review to identify blocking questions before editing. Execute tasks in order unless this plan explicitly marks tasks independent.

**Status:** Draft | Approved
**Source of truth:** [conversation summary, issue, spec, or design doc]

## Goal

## Recommended approach

## Steps
1. ...
2. ...

## Verification

## Risks / open questions
```

## Agent Handoff Marker

When writing a durable implementation plan file, include this marker verbatim near the top:

```markdown
> **Agent handoff:** When asked to implement this plan, use the `subagent-driven-implementation` skill. Start with a readonly planner or reviewer subagent plan review to identify blocking questions before editing. Execute tasks in order unless this plan explicitly marks tasks independent.
```

If the plan is not approved yet, mark `**Status:** Draft`. Do not imply approval. If the user approves the plan, update or state the approved status clearly before implementation.

## Quality Bar

A good plan should be specific enough that another agent could implement it without re-litigating the design, but not so detailed that it invents code before the relevant files are inspected.
