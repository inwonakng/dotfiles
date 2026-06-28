---
name: defer-driven-implementation
description: Use when executing an approved implementation plan file, multiple plan files, or a complex approved conversation plan that should be coordinated through deferred Pi subagents. Mandatory by default for plan-file execution unless the user explicitly requests inline implementation.
---

# Defer-Driven Implementation

Use this skill to execute approved implementation plans through a main-agent controller and bounded deferred Pi subagents.

This is the high-level workflow. The `defer` skill is the low-level policy for using `defer_task` safely. Load and follow `defer` before the first `defer_task` call in this workflow.

## Non-Negotiable Trigger

You MUST use this skill when the user asks to implement, apply, execute, continue, or finish work from an approved implementation plan file.

You MUST also use this skill for a complex approved conversation plan when the user asks for implementation and the work has multiple slices, meaningful review risk, or would benefit from fresh context.

Do not silently execute a plan file inline. If a plan file exists and is the source of implementation truth, this workflow is the default.

Inline implementation is allowed only when:

- there is no implementation plan file and the task is small/local, or
- the user explicitly requests inline execution, or
- this workflow is blocked/unavailable and the user agrees to continue inline.

## When to Stop and Ask First

Ask a concise clarification before editing if:

- no specific plan file is identified and multiple plausible plan files exist
- the referenced plan is marked Draft, unapproved, stale, or superseded
- the artifact is a design/spec/notes file rather than an implementation plan
- the plan has unresolved questions that block safe implementation
- multiple plan files are implied but the execution order is unclear
- the plan asks for risky or broad changes not clearly approved by the user

Batch related questions. Do not drip-feed one avoidable question per turn.

## Controller Responsibilities

The main agent is the controller and remains accountable for the result.

The controller MUST:

- preserve the user's approved intent and plan-file requirements
- decide which tasks to delegate and which to do inline
- write precise deferred briefs with bounded scope
- answer or escalate deferred-agent questions
- integrate deferred results
- resolve conflicts and contradictions
- verify final behavior directly
- report what was changed, verified, and left unverified

Never treat a deferred agent's success report as proof. Always verify important claims before completion.

## Execution Modes

### Default: Sequential plan execution

Execute plan files sequentially unless the user explicitly requests parallel execution or the plan clearly marks tasks as independent.

Within a plan, execute tasks in order unless the plan states otherwise. Do not reorder tasks just because it seems convenient.

### Readonly defer is encouraged

Use readonly deferred agents freely for bounded:

- plan review / question discovery
- subsystem research
- implementation approach critique
- diff or task review
- verification advice

### Write defer is selective

Use write deferred agents only when:

- the user has approved implementation, and
- the task is bounded to specific files or a natural isolated slice, and
- write conflicts are unlikely, and
- the deferred brief states exact scope and verification expectations.

Do not run multiple write deferred agents against the same worktree unless the edits are provably non-overlapping and the user accepted the risk.

## Workflow

### 1. Identify the source of truth

Read the referenced plan file(s), or identify the approved conversation plan if no file exists.

If plan files are involved, record:

- exact path(s)
- approval status if present
- unresolved questions
- task list / natural slices
- verification commands or checks
- constraints and out-of-scope items

If multiple possible plan files exist and the user did not specify which ones to implement, stop and ask.

### 2. Create session todos

For non-trivial work, use `todowrite` before editing. Include at least:

1. plan preflight / question review
2. implementation slices or plan files
3. review / fix findings
4. final verification

Keep exactly one todo in progress.

### 3. Run deferred plan preflight

Before editing a plan-file implementation, use `defer_task` in readonly mode with role `planner` or `reviewer` to inspect the plan for:

- blocking ambiguities
- missing context
- contradictions within the plan
- mismatch between plan and current code structure
- risky assumptions
- task ordering problems
- verification gaps

The brief must point to the plan file path(s) and ask for a concise result with:

- `Status: DONE | NEEDS_CONTEXT | BLOCKED`
- blocking questions, if any
- non-blocking risks
- recommended execution slices
- evidence inspected

If the plan is tiny and purely mechanical, you may skip this preflight only if you state why in your own reasoning and proceed with normal `implement` safeguards. Do not skip preflight for multi-task plan files.

### 4. Handle preflight result

- `NEEDS_CONTEXT`: ask the user the blocking questions. Do not edit until resolved.
- `BLOCKED`: decide whether to inspect inline, ask the user, or stop.
- `DONE` with blocking issues: ask or resolve from evidence before editing.
- `DONE` with only non-blocking risks: proceed and track the risks.

Do not ignore a deferred agent's questions or concerns.

### 5. Implement one slice at a time

For each plan task or natural slice:

1. inspect the smallest relevant context
2. decide inline vs bounded write defer
3. implement the slice
4. run the smallest meaningful verification for that slice
5. review the slice when risk justifies it
6. fix Critical/Important findings before continuing
7. update todos

Prefer inline edits for small tightly-coupled changes. Prefer bounded write defer for isolated, well-specified slices from a strong plan.

### 6. Review gates

Use readonly deferred review for non-trivial slices and before final completion of a plan-file implementation.

A review brief should include:

- plan path and task/slice identifier
- files changed or diff command to inspect
- requirements to check
- verification already run
- requested severity format: Critical, Important, Minor, Question

Critical and Important findings block completion. Fix them or ask the user if the finding conflicts with the approved plan.

### 7. Final verification

After all slices are complete, use the `verify` skill before claiming done.

Run or inspect the smallest evidence that proves:

- the implementation satisfies the plan
- relevant tests/build/typechecks pass where applicable
- deferred-agent claims that matter are backed by current evidence

If verification cannot be run, say why and what was checked instead.

## Deferred Brief Template

Use this shape for delegated work:

```text
Goal: [one sentence]

Context:
- cwd/repo context
- plan file path(s): ...
- task/slice: ...
- relevant files or commands to inspect

Task:
1. ...
2. ...

Constraints:
- access mode: readonly/write
- exact files allowed for write tasks, if any
- do not broaden scope
- do not make product/design decisions not approved by the user

Return:
- Status: DONE | BLOCKED | NEEDS_CONTEXT
- Evidence inspected
- Commands run
- Blocking questions
- Findings / changes made
- Verification result or verification advice
- Artifact paths, if any
```

## Plan-File Handoff Marker

When this workflow is invoked from a plan file, treat any explicit plan-file handoff instructions as binding unless they conflict with the user or higher-priority instructions.

Recommended marker for future plans:

```markdown
> **Agent handoff:** When asked to implement this plan, use the `defer-driven-implementation` skill. Start with a readonly deferred plan review to identify blocking questions before editing. Execute tasks in order unless this plan explicitly marks tasks independent.
```

## Red Flags

Stop and correct course if you notice any of these:

- implementing a plan file inline without using this skill
- skipping plan preflight for a multi-task plan file
- running write deferred agents with vague scope
- dispatching multiple write agents that may touch the same files
- treating a deferred report as verified fact
- continuing after `NEEDS_CONTEXT` without answering the missing context
- fixing reviewer Critical/Important findings without rechecking the relevant behavior
- broadening the plan because it seems useful
- asking the user to approve implementation after they already clearly did, instead of executing

## Final Response Shape

Report concisely:

- plan file(s) executed
- key changes made
- deferred agents used and for what
- verification run and result
- anything not verified
- remaining risks or follow-up decisions
