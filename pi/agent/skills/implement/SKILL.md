---
name: implement
description: Use when the user explicitly asks to implement, fix, add, remove, refactor, apply, write code, or execute an approved plan. Delivers the smallest complete solution and routes approved plan-file or complex-plan execution to subagent-driven-implementation.
---

# Implement

Use this skill as the entry point whenever the user explicitly asks for file changes or implementation.

This skill is a router and implementation workflow. It decides whether to execute a local change inline or coordinate a plan-file or complex-plan implementation through `subagent-driven-implementation`.

## Entry Checks

Before editing:

1. Confirm the user explicitly asked for implementation or file changes.
2. Identify the source of truth:
   - If the user points at a plan file, read it first.
   - If the user says to implement/apply/execute/continue an approved plan file, load and use `subagent-driven-implementation`. This is mandatory by default.
   - If multiple plausible plan files exist and the user did not identify which to execute, ask before editing.
   - If the plan file is marked Draft/unapproved or contains unresolved blocking questions, ask before editing.
   - Use the approved conversation plan if present and no plan file exists.
   - If no clear plan exists, identify the current behavior, desired behavior, affected contracts, and verification path before editing.
3. If the task is a bug/test failure/unexpected behavior, use the `debug` skill before changing code.
4. For non-trivial multi-step work, use `todowrite` to track progress.

## Execution Rules

- Optimize in this order: correctness, the user's intended behavior, maintainability, then speed and diff size.
- Deliver the smallest complete solution. Scope control excludes unrelated work; it does not permit temporary workarounds, duplicated logic, suppressed errors, weakened tests, or omitted callers.
- Follow the agreed plan unless code evidence shows it is wrong, unsafe, or incomplete.
- Explain before proceeding if the necessary change would alter agreed behavior, a public interface, persisted data, dependencies, security properties, or the approved architecture.
- Keep edits limited to the task. Do not perform unrelated cleanup.
- Respect unrelated worktree changes.
- Avoid speculative abstractions and invented compatibility requirements.
- A behavior test is useful when it would fail if the changed requirement regressed and asserts an observable result rather than an implementation detail. Add or update such a test when the project has a suitable test location; otherwise state the verification used instead.

## Plan-File Execution

If implementation is driven by an approved implementation plan file, multiple plan files, or a complex approved conversation plan, do not execute it inline by default. Load `subagent-driven-implementation` and follow that workflow.

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

For non-plan-file work, use the `subagent-delegation` skill when isolated context would reduce noise, provide an independent judgment, or separate non-overlapping implementation work. Also use it when the user says "use subagents". Typical uses:

- readonly research into an unfamiliar subsystem
- independent review of a plan or diff
- implementation tasks with explicit user approval and exact file scope

Do not delegate just to avoid reasoning. The main agent remains responsible for integrating subagent results, resolving conflicts, and verifying the final state.

## Implementation Loop

For each task or independently verifiable slice:

1. Inspect the code needed to identify the affected behavior, contracts, consumers, and failure cases.
2. Make the least complex edit that fully satisfies those requirements.
3. Run the fastest check capable of falsifying the changed behavior.
4. Run broader checks required by the affected contract.
5. If verification fails, use the `debug` skill rather than guessing.
6. Update todo status if using `todowrite`.

Use a readonly reviewer after a slice that changes a shared or public interface, security or data behavior, concurrency, or more than one subsystem. Also use a reviewer when a write subagent changed files. Join the reviewer before relying on its findings, and fix Critical or Important findings before proceeding.

If the task develops unresolved design choices or expands across independently sequenced changes, stop and confirm a plan or route to `subagent-driven-implementation`.

## Completion Gate

Before claiming the work is complete, use the `verify` skill and follow its evidence and response requirements.
