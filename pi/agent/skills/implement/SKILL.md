---
name: implement
description: Use when the user explicitly asks to implement, fix, add, remove, refactor, apply, write code, or execute an approved plan. Performs changes, coordinates bounded deferred work when useful, and verifies results.
---

# Implement

Use this skill to execute an approved direction and deliver verified code changes.

This adapts Superpowers' executing-plans and subagent-driven-development ideas for Pi: the main agent remains the coordinator, and `defer_task` is used selectively for bounded isolated work.

## Entry Checks

Before editing:

1. Confirm the user explicitly asked for implementation or file changes.
2. Identify the plan to execute:
   - Use the approved conversation plan if present.
   - If the user points at a plan file, read it first.
   - If no clear plan exists, inspect enough context and make a brief plan before editing.
3. If the task is a bug/test failure/unexpected behavior, use the `debug` skill before changing code.
4. For non-trivial multi-step work, use `todowrite` to track progress.

## Execution Rules

- Follow the agreed plan unless code evidence shows it is wrong, unsafe, or incomplete.
- If a material deviation is needed, explain why before changing direction.
- Keep edits focused on the task. Do not perform unrelated cleanup.
- Respect unrelated worktree changes.
- Avoid speculative abstractions and invented compatibility requirements.
- Do not write trivial tests. Add or update tests only when they verify meaningful behavior.

## Deferred Work

Use the `defer` skill when delegation would help. Typical uses:

- readonly research into an unfamiliar subsystem
- independent review of a plan or diff
- bounded implementation tasks with explicit user approval for write access

Do not delegate just to avoid reasoning. The main agent remains responsible for integrating deferred results, resolving conflicts, and verifying the final state.

## Implementation Loop

For each task or natural slice:

1. Inspect the smallest relevant context.
2. Make the smallest coherent edit.
3. Run the smallest relevant verification.
4. If verification fails, use the `debug` skill rather than guessing.
5. Update todo status if using `todowrite`.

For complex tasks, consider this stricter loop:

1. Implement one slice.
2. Run local verification for that slice.
3. Use `defer_task` in readonly mode with role `reviewer` for a focused review.
4. Fix Critical/Important findings before moving on.

## Completion Gate

Before claiming the work is complete, use the `verify` skill.

Final response must state:

- what changed
- what verification was run and the result
- anything not verified
- any follow-up risks or decisions
