---
name: subagent-delegation
description: Use before delegating a clearly scoped research, planning, implementation, review, or verification task to a Pi subagent. Defines access modes, brief requirements, join behavior, and controller responsibilities.
---

# Subagent Delegation

Use this skill to coordinate clearly scoped delegation to isolated Pi subagents through the `spawn` and `spawn_control` tools.

"Subagents" is the user-facing concept. `spawn` starts a subagent job and `spawn_control` inspects, joins, or stops it.

## Relationship to Other Skills

- Use `plan` when the work needs main-agent implementation planning or user approval before edits. Planner subagents can help, but they do not own the source-of-truth plan.
- Use `subagent-driven-implementation` when executing an approved implementation plan file, multiple plan files, or a complex approved implementation plan. That skill is the high-level workflow; this skill is the low-level delegation policy.
- Use this skill directly for research into a named subsystem, independent critique or review, verification advice, or implementation with exact file scope that does not require the full plan-file workflow.

## When to Delegate

A subagent task is scoped when the brief names its goal, files or systems to inspect, permitted actions, required evidence, and return conditions.

Good uses:

- research into a named unfamiliar subsystem
- independent plan critique
- fresh-context code review
- investigation of a specific failure or code path
- approved implementation with exact, non-overlapping file scope

Bad uses:

- tiny tasks the main agent can do directly
- avoiding your own reasoning
- work with no named deliverable or stop condition
- parallel write work against overlapping files
- asking a subagent to make product or design decisions the user has not approved

## Execution Model

- `spawn` defaults to `mode: "background"` and returns a run id immediately.
- If the parent answer depends on child output, call `spawn_control` with `action: "join"` or `"join_all"` before answering.
- Background completion is recorded as a notification/context message for the next parent turn, but it does not automatically trigger a parent turn.
- Parent abort stops children spawned in that active turn. Session shutdown stops all live children.

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

- the user explicitly approved implementation,
- the brief names the exact files or directory the subagent may change,
- the required behavior and verification are stated, and
- worktree isolation is appropriate.

Write-capable spawned subagents use isolated worktrees. On `join`, clean changes may be applied automatically; conflicts or overlapping parent changes are returned for the parent to handle manually.

Do not run multiple write subagents against overlapping files. If overlap becomes necessary, run the work sequentially or keep one writer and use readonly reviewers.

## Main Agent Responsibilities

The main agent remains responsible for:

- choosing whether delegation is appropriate
- writing a brief with a named goal, scope, evidence, and return conditions
- deciding whether to wait or continue
- joining before relying on subagent results
- integrating any conflicted/unsafe worktree changes
- resolving conflicts or inconsistencies
- verifying final behavior
- reporting what was and was not done

Never treat a subagent's success report as proof. Use the `verify` skill before completion claims.

## Brief Template

Use a complete scoped prompt. Prefer references to files or artifacts over pasting large content.

```text
Goal: [one sentence]

Context:
- cwd/repo context
- plan or specification path, if any
- exact files, systems, or commands to inspect

Task:
1. ...
2. ...

Constraints:
- access mode
- exact files allowed for write tasks
- decisions the subagent must not make
- stop conditions

Return:
- Status: DONE | BLOCKED | NEEDS_CONTEXT
- Evidence inspected
- Commands run
- Findings
- Changes made, if any
- Uncertainty or unverified claims
- Artifact paths, if any
```

## Role Guidance

Prefer named subagent profiles with the `agent` parameter when available. Profiles are loaded from `~/.pi/agent/agents/*.md` and trusted `.pi/agents/*.md`; they provide durable prompts and defaults. The `role` parameter remains a lightweight fallback and backward-compatible alias when it matches a profile.

Common profiles / roles:

- `researcher`: inspect and summarize evidence, no edits.
- `planner`: critique or refine a plan, no edits unless asked to write a plan file.
- `implementer`: make an approved change within exact file scope and run the stated verification.
- `reviewer`: inspect diff/plan for correctness, risks, tests, and requirement coverage.
- `verifier`: gather verification evidence and identify unverified claims, no edits.

## Tool Use Pattern

For fanout/fanin:

```text
spawn({ agent: "researcher", prompt: "..." })
spawn({ agent: "reviewer", prompt: "..." })
spawn_control({ action: "join_all" })
```

For a result needed immediately:

```text
spawn({ agent: "researcher", prompt: "...", mode: "foreground" })
```

## After Spawn Returns

1. If the spawn was foreground, read the result carefully.
2. If the spawn was background and the result matters, call `spawn_control join` or `join_all`.
3. If status is `NEEDS_CONTEXT`, provide missing context and re-dispatch only if still worthwhile.
4. If status is `BLOCKED`, decide whether to unblock, do the work inline, or ask the user.
5. If status is `DONE`, verify the important claims before relying on them.
6. If join reports `integration=needs_parent`, inspect/apply the returned patch only if appropriate.
