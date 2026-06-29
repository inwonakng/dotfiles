---
name: implement
description: Use when the user explicitly asks to implement, fix, add, remove, refactor, apply, write code, or execute an approved plan. Routes approved plan-file execution to subagent-driven-implementation by default; otherwise performs focused changes and verifies results.
---

# Implement

Use this skill as the entry point whenever the user explicitly asks for file changes or implementation.

This skill is a router and guardrail. It decides whether to execute a small change inline or hand a plan-file / complex-plan implementation to `subagent-driven-implementation`. Do not treat all implementation requests the same.

## Entry Checks

Before editing:

1. Confirm the user explicitly asked for implementation or file changes.
2. Identify the source of truth:
   - If the user points at a plan file, read it first.
   - If the user says to implement/apply/execute/continue an approved plan file, load and use `subagent-driven-implementation`. This is mandatory by default.
   - If multiple plausible plan files exist and the user did not identify which to execute, ask before editing.
   - If the plan file is marked Draft/unapproved or contains unresolved blocking questions, ask before editing.
   - Use the approved conversation plan if present and no plan file exists.
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

## Plan-File Execution

If implementation is driven by an approved implementation plan file, do not execute it inline by default. Load `subagent-driven-implementation` and follow that workflow.

This applies when the user says things like:

- "implement this plan"
- "apply `plans/foo.md`"
- "execute the approved plan"
- "continue from the plan file"
- "now implement" after the current discussion saved or identified a plan file

Inline execution is allowed only when:

- there is no implementation plan file and the task is small/local, or
- the user explicitly requests inline execution, or
- `subagent-driven-implementation` is blocked/unavailable and the user agrees to continue inline.

Do not silently downgrade a plan-file implementation to inline work.

## Subagent Work

For non-plan-file work, use the `defer` skill when subagent delegation would materially help or the user says "use subagents". Typical uses:

- readonly research into an unfamiliar subsystem
- independent review of a plan or diff
- bounded implementation tasks with explicit user approval for write access

Do not delegate just to avoid reasoning. The main agent remains responsible for integrating subagent results, resolving conflicts, and verifying the final state.

## Implementation Loop

For each task or natural slice:

1. Inspect the smallest relevant context.
2. Make the smallest coherent edit.
3. Run the smallest relevant verification.
4. If verification fails, use the `debug` skill rather than guessing.
5. Update todo status if using `todowrite`.

For complex tasks without a plan file, prefer this stricter loop:

1. Implement one slice.
2. Run local verification for that slice.
3. Use `defer_task` in readonly mode with `agent: "reviewer"` for a focused review.
4. Fix Critical/Important findings before moving on.

If the complex task becomes plan-shaped, stop and either write/confirm a plan or route to `subagent-driven-implementation`.

## Completion Gate

Before claiming the work is complete, use the `verify` skill.

Final response must state:

- what changed
- what verification was run and the result
- anything not verified
- any follow-up risks or decisions
