---
name: subagent-driven-implementation
description: Use when executing an approved implementation plan file, multiple plan files, or a complex approved conversation plan that should be coordinated through subagents. Mandatory by default for plan-file execution unless the user explicitly requests inline implementation.
---

# Subagent-Driven Implementation

Use this skill to execute approved implementation plans through a main-agent controller and clearly scoped Pi subagents.

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
- write subagent briefs with a named goal, exact scope, required evidence, and return conditions
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

Use readonly subagents for:

- plan review and blocking-question discovery
- research into a named subsystem
- critique of a stated implementation approach
- review of a named diff or task
- advice on how to verify a specific claim

### Write subagents are selective

Use write subagents only when:

- the user has approved implementation,
- the task has exact, non-overlapping file scope,
- the required behavior and verification are stated, and
- worktree integration is appropriate.

Do not run multiple write subagents against overlapping files. If tasks share files, run them sequentially or assign one writer and use readonly reviewers.

## Workflow

### 1. Identify the source of truth

Read the referenced plan file(s), or identify the approved conversation plan if no file exists.

If plan files are involved, record:

- exact path(s)
- approval status if present
- unresolved questions
- task list and independently verifiable slices
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

Before editing a multi-task plan file or complex approved conversation plan, use `spawn` in readonly mode with `agent: "planner"` or `agent: "reviewer"` to inspect the plan and current code structure. Join the subagent before relying on its result. Ask it to check for:

- blocking ambiguities
- missing context
- contradictions within the plan
- mismatch between plan and current code structure
- assumptions unsupported by inspected evidence
- task ordering problems
- requirements or affected contracts without verification

The brief must point to the plan file path(s) and ask for a concise result with:

- `Status: DONE | NEEDS_CONTEXT | BLOCKED`
- blocking questions, if any
- non-blocking risks
- recommended execution slices
- evidence inspected

You may skip preflight only when the work is one mechanical edit with no design choice and no shared behavior change. Do not skip it for multi-task plans.

### 4. Handle preflight result

- `NEEDS_CONTEXT`: ask the user the blocking questions. Do not edit until resolved.
- `BLOCKED`: decide whether to inspect inline, ask the user, or stop.
- `DONE` with blocking issues: ask or resolve from evidence before editing.
- `DONE` with only non-blocking risks: proceed and track the risks.

Do not ignore a subagent's questions or concerns.

### 5. Implement one slice at a time

For each plan task or independently verifiable slice:

1. identify the requirement, affected contract, and expected evidence
2. inspect the code needed to understand its consumers and failure cases
3. decide between inline work and a write subagent with exact file scope
4. implement the complete slice
5. run the fastest check capable of falsifying its changed behavior
6. run broader checks required by the affected contract
7. review when the slice changes a shared or public interface, security or data behavior, concurrency, or more than one subsystem
8. fix Critical or Important findings before continuing
9. update todos

Prefer inline edits for tightly coupled changes. Prefer write subagents only when file ownership and verification can be stated without ambiguity.

### 6. Review gates

Use readonly subagent review for slices that change shared or public interfaces, security or persisted data, concurrency, or multiple subsystems. Also review any slice written by a subagent and the final combined diff for a multi-task plan.

A review brief should include:

- plan path and task/slice identifier
- files changed or diff command to inspect
- requirements to check
- verification already run
- requested severity format: Critical, Important, Minor, Question

Critical and Important findings block completion. Fix them or ask the user if the finding conflicts with the approved plan.

### 7. Final verification

After all slices are complete, use the `verify` skill before claiming done.

Match each completion claim to current evidence:

- trace every plan requirement to implementation and a verification result
- run tests for changed behavior and affected consumers
- run build or typecheck when exported types, configuration, or compilation paths changed
- exercise a runtime flow when claiming user-visible behavior works
- inspect the current diff before accepting subagent claims

If verification cannot be run, say why and what was checked instead.

## Subagent Brief Additions

Start from the brief template in `subagent-delegation`. For plan execution, also include:

- plan path and task identifier
- requirement and affected contract for the slice
- verification expected before return
- blocking questions as a separate return field

## Plan-File Handoff

When this workflow is invoked from a plan file, follow the handoff marker written by the `plan` skill unless it conflicts with the user or higher-priority instructions. The `plan` skill owns the canonical marker text.

## Red Flags

Stop and correct course if you notice any of these:

- implementing a plan file inline without using this skill
- skipping plan preflight for a multi-task plan file
- running write subagents without exact file scope, required behavior, and verification
- dispatching multiple write subagents that may touch the same files
- treating a subagent report as verified fact
- continuing after `NEEDS_CONTEXT` without answering the missing context
- fixing reviewer Critical or Important findings without rechecking the behavior named in the finding
- broadening the plan because it seems useful
- asking the user to approve implementation after they already clearly did, instead of executing

## Final Response

Follow the `verify` skill's response requirements. Also identify the plan or approved conversation direction executed and the scope assigned to each subagent.
