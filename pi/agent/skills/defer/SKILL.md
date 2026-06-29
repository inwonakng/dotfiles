---
name: defer
description: Use when a task may benefit from an isolated Pi subagent for research, planning, implementation, review, or verification. Teaches when and how to call the defer_task tool safely.
---

# Defer

Use this skill to coordinate isolated Pi subagents through the `defer_task` tool.

"Subagents" is the user-facing concept. `defer_task` is the underlying mechanism and artifact runner.

## Relationship to Other Skills

- Use `plan` when the work needs main-agent implementation planning or user approval before edits. Planner subagents can help, but they do not own the source-of-truth plan.
- Use `subagent-driven-implementation` when executing an approved implementation plan file, multiple plan files, or a complex approved implementation plan. That skill is the high-level workflow; this skill is the low-level delegation policy.
- Use this skill directly for bounded research, critique, review, verification advice, or isolated implementation slices that do not require the full plan-file workflow.

## When to Defer

Good uses:

- bounded research into an unfamiliar subsystem
- independent plan critique
- fresh-context code review
- focused bug investigation
- a clearly scoped implementation slice after the user has approved implementation

Bad uses:

- tiny tasks the main agent can do directly
- avoiding your own reasoning
- broad ambiguous work with no crisp deliverable
- parallel write work in the same worktree without isolation
- asking a subagent to make product/design decisions the user has not approved

## Access Modes

### `readonly`

Default to readonly for:

- research
- planning
- debugging investigation
- review
- verification advice

Readonly subagents must not modify files. If blocked by missing write access, they should report `BLOCKED` with the exact action they could not take.

### `write`

Use write only when:

- the user explicitly approved implementation, and
- the delegated task is bounded, and
- write conflicts are unlikely or isolated.

Do not run multiple write subagents against the same worktree unless each has its own isolated worktree or the tasks are provably non-overlapping and the user accepted the risk.

## Main Agent Responsibilities

The main agent remains responsible for:

- choosing whether delegation is appropriate
- writing a precise brief
- integrating the result
- resolving conflicts or inconsistencies
- verifying final behavior
- reporting what was and was not done

Never treat a subagent's success report as proof. Use the `verify` skill before completion claims.

## Brief Template

Use a complete bounded task. Prefer references to files/artifacts over pasting huge context.

```text
Goal: [one sentence]

Context:
- cwd/repo context
- relevant plan/spec path if any
- relevant files or commands to inspect

Task:
1. ...
2. ...

Constraints:
- access mode expectations
- do not modify files / or exact files allowed
- stay within this scope

Return:
- Status: DONE | BLOCKED | NEEDS_CONTEXT
- Evidence inspected
- Commands run
- Findings / changes made
- Artifact paths, if any
```

## Role Guidance

Prefer named subagent profiles with the `agent` parameter when available. Profiles are loaded from `~/.pi/agent/agents/*.md` and trusted `.pi/agents/*.md`; they provide durable prompts and defaults. The `role` parameter remains a lightweight fallback and backward-compatible alias when it matches a profile.

Common profiles / roles:

- `researcher`: inspect and summarize evidence, no edits.
- `planner`: critique or refine a plan, no edits unless asked to write a plan file.
- `implementer`: make the bounded approved change and run local verification.
- `reviewer`: inspect diff/plan for correctness, risks, tests, and requirement coverage.
- `verifier`: gather verification evidence and identify unverified claims, no edits.

## After Defer Returns

1. Read the result carefully.
2. If status is `NEEDS_CONTEXT`, provide missing context and re-dispatch only if still worthwhile.
3. If status is `BLOCKED`, decide whether to unblock, do the work inline, or ask the user.
4. If status is `DONE`, verify the important claims before relying on them.
5. Integrate only the useful parts into the main workflow.
