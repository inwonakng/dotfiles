---
name: review
description: Use when reviewing a plan, diff, implementation, branch, or completed task. Checks requirements, correctness, maintainability, test quality, and risks before work is considered done.
---

# Review

Review requirements and evidence before judging implementation quality. Use `write-good-code` for code or code-changing plans.

Review is especially useful for shared interfaces, security, persisted data, concurrency, multiple subsystems, spawned implementations, and work approaching completion, merge, or handoff.

## Choose the scope

Outside active orchestration, review a small diff or conceptual answer inline: read the requirements, inspect changed files and affected contracts, check coverage, and report findings by severity. During orchestration, delegate detailed review and evaluate the returned evidence. Spawned workers review their assignment directly and must not delegate.

Use a readonly reviewer subagent during orchestration, or when independent context would reduce author bias or keep a large diff out of the main conversation. Follow the packaged `orchestration` skill through its advertised path and join before relying on findings. Specify requirements, exact paths or a diff command, affected contracts and failure modes, checks already run, and the return format. Reference file artifacts or commands instead of pasting large diffs.

## Check requirements

- Trace each requested behavior to its implementation.
- Trace changed behavior to evidence that would detect regression.
- Check affected callers, public interfaces, configuration, persisted data, and user-visible flows.
- Confirm deviations from the approved plan were explained before implementation.

## Check implementation quality

- Does the change address the cause or core requirement?
- Are failure and boundary cases handled through project conventions?
- Would tests detect a requirement regression rather than only implementation changes?
- Is the design the least complex option that preserves required behavior, contracts, and error handling?
- Does it follow project patterns without speculative compatibility or unrelated cleanup?
- Are abstractions, dependencies, public API changes, and Python annotations justified by the code and project conventions?

## Grade findings

- Critical: incorrect behavior, data loss, security issue, broken build, or an explicit requirement violation. Must fix before proceeding.
- Important: likely bug, missing regression coverage, or a design issue likely to cause near-term failures or rework. Should fix before proceeding.
- Minor: clarity, naming, cleanup, or optional refactor. Track or fix when cheap.
- Question: ambiguity requiring a user or implementer decision.

## Report

Lead with consequential findings. Give severity, `file:line`, the issue, and its consequence. If there are none, say so without inventing minor findings.

Include the status (`APPROVED`, `APPROVED_WITH_MINOR_NOTES`, `CHANGES_REQUESTED`, or `BLOCKED`), concise evidence inspected, commands and results if any, and a recommendation when action is needed. Avoid repeating findings in a closing recap.

Approve only after inspecting relevant evidence. State unverified behavior separately.
