---
name: subagent-driven-implementation
description: Use when executing an approved implementation plan file, multiple plan files, or a complex approved conversation plan that should be coordinated through subagents. Mandatory by default for plan-file execution unless the user explicitly requests inline implementation.
---

# Subagent-Driven Implementation

Use this skill to execute approved implementation plans through a main-agent controller and bounded Pi subagents.

This is the high-level implementation workflow. The `subagent-delegation` skill is the low-level policy for using `spawn` / `spawn_control` safely. Load and follow `subagent-delegation` before the first spawned subagent in this workflow.

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
- write precise subagent briefs with bounded scope
- answer or escalate subagent questions
- integrate subagent results
- resolve conflicts and contradictions
- verify final behavior directly
- report what was changed, verified, and left unverified

Never treat a subagent's success report as proof. Always verify important claims before completion.

## Execution Modes

### Default: Sequential plan execution

Execute plan files sequentially unless the user explicitly requests parallel execution or the plan clearly marks tasks as independent.

Within a plan, execute tasks in order unless the plan states otherwise. Do not reorder tasks just because it seems convenient.

### Readonly subagents are encouraged

Use readonly subagents freely for bounded:

- plan review / question discovery
- subsystem research
- implementation approach critique
- diff or task review
- verification advice

### Write subagents are selective

Use write subagents only when:

- the user has approved implementation, and
- the task is bounded to specific files or a natural isolated slice, and
- write conflicts are unlikely, and
- the subagent brief states exact scope and verification expectations.

Do not run multiple write subagents against the same worktree unless the edits are provably non-overlapping and the user accepted the risk.

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

### 3. Run subagent plan preflight

Before editing a plan-file implementation, use `spawn` in readonly mode with `agent: "planner"` or `agent: "reviewer"` to inspect the plan, then `spawn_control join` before relying on its result. Ask it to check for:

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

Do not ignore a subagent's questions or concerns.

### 5. Implement one slice at a time

For each plan task or natural slice:

1. inspect the smallest relevant context
2. decide inline vs bounded write subagent
3. implement the slice
4. run the smallest meaningful verification for that slice
5. review the slice when risk justifies it
6. fix Critical/Important findings before continuing
7. update todos

Prefer inline edits for small tightly-coupled changes. Prefer bounded write subagents for isolated, well-specified slices from a strong plan.

### 6. Review gates

Use readonly subagent review for non-trivial slices and before final completion of a plan-file implementation.

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
- subagent claims that matter are backed by current evidence

If verification cannot be run, say why and what was checked instead.

## Subagent Brief Template

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
> **Agent handoff:** When asked to implement this plan, use the `subagent-driven-implementation` skill. Start with a readonly planner or reviewer subagent plan review to identify blocking questions before editing. Execute tasks in order unless this plan explicitly marks tasks independent.
```

## Red Flags

Stop and correct course if you notice any of these:

- implementing a plan file inline without using this skill
- skipping plan preflight for a multi-task plan file
- running write subagents with vague scope
- dispatching multiple write subagents that may touch the same files
- treating a subagent report as verified fact
- continuing after `NEEDS_CONTEXT` without answering the missing context
- fixing reviewer Critical/Important findings without rechecking the relevant behavior
- broadening the plan because it seems useful
- asking the user to approve implementation after they already clearly did, instead of executing

## Final Response Shape

Report concisely:

- plan file(s) executed
- key changes made
- subagents used and for what
- verification run and result
- anything not verified
- remaining risks or follow-up decisions
