---
name: subagent-delegation
description: Use before delegating a bounded research, planning, implementation, review, or verification task to a Pi subagent. Defines scope, access, joining, and main-agent responsibility.
---

# Subagent delegation

Delegate bounded work with a clear goal that can return a useful result without resolving user or design decisions.

Suitable tasks include code or documentation research, investigation of a named failure or subsystem, independent review, verification of a specific claim, and approved implementation with non-overlapping file ownership. Keep tiny tasks, vague work, and overlapping edits in the main session.

## Choose access

Use `readonly` for research, planning, investigation, review, and verification.

Use `edit` only after implementation approval, with exact file or directory scope, settled behavior, clear verification, and no overlap with another writer.

## Write the brief

Specify the goal, relevant context and paths, permitted actions, constraints, decisions the subagent must not make, required evidence, and expected return.

Request `DONE`, `BLOCKED`, or `NEEDS_CONTEXT`, followed by concise findings, changes, evidence or commands, and remaining uncertainty as applicable. Do not request a process diary.

## Respect workspace ownership

- Edit-mode subagents use the isolated child workspace assigned by `spawn`; they must not create another worktree.
- Children inherit the immediate parent's tracked working state and non-ignored untracked files, including additions and deletions.
- Join integrates the child's contribution relative to that baseline into the immediate parent, not the original checkout.
- Compatible parent changes are preserved. Conflicts retain the child worktree and recovery artifacts without changing the parent.
- Treat `integration=needs_parent` or `integration=failed` as unresolved. Inspect the reported workspace, patch, and conflict diagnostics rather than applying a blind patch.

## Retain main-agent responsibility

Keep user intent and unresolved decisions in the main conversation. Join background work before relying on it. Inspect and integrate returned work, resolve conflicts, verify important claims directly, and report remaining uncertainty.

Use `verify` before completion claims; a subagent's success statement is not proof.
