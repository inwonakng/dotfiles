---
name: plan
description: Use when the user asks to plan, design, or compare implementation approaches, or when an unresolved design decision blocks implementation. Produces a concise plan for discussion and approval without changing code.
---

# Plan

Use this skill to agree on an implementation approach before changing code. Planning normally stays in the current conversation so the implementation keeps the user's context and decisions.

## Rules

- Do not modify files unless the user explicitly asks you to save the plan.
- Inspect the relevant code and documentation before proposing changes.
- Resolve repository facts through inspection. Ask the user only about intent, constraints, or tradeoffs that cannot be discovered.
- Ask only questions whose answers could materially change the plan.
- Use the `write-good-code` skill when planning code changes.
- The main agent owns the plan. If the user asks for subagents, or bounded research would keep substantial exploration out of the main context, load `subagent-delegation` and use readonly subagents.
- Do not continue into implementation without an explicit request.

## Process

1. Establish the goal, success criteria, constraints, and important exclusions.
2. Inspect the current behavior, affected contracts, existing patterns, and available verification.
3. Resolve important design choices. Present alternatives only when they have real differences in behavior, cost, or risk.
4. Produce the shortest plan that leaves no important decision unresolved.

## Plan Shape

Use only the sections that help:

```markdown
# [Name]

## Goal

## Approach

## Changes

## Verification

## Assumptions or open questions
```

Prefer behavior and contracts over a long file-by-file inventory. Name files or symbols when they prevent ambiguity. Keep assumptions and open questions separate, and do not present a final plan while blocking questions remain.

If the user wants a standalone document for a fresh session or another agent, use the `prepare-spec` skill instead.

After presenting the plan, stop and let the user approve or revise it.
