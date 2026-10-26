---
name: implement
description: Use when the user explicitly asks to implement, fix, add, remove, refactor, apply, write code, or execute an approved plan or specification. Delivers the smallest complete change and verifies the result.
---

# Implement

Make the smallest complete change that satisfies the approved behavior and affected contracts.

## Before editing

1. Identify the requested outcome and source of truth: the conversation, an approved plan, or a specification.
2. Resolve draft status, blocking questions, or conflicts with the current request before editing.
3. Inspect the current code and check the plan's assumptions. Explain conflicts that would change the agreed behavior or approach.
4. Use `debug` for failures or unexpected behavior and `write-good-code` for code changes.
5. Use `todowrite` for work with several distinct steps.
6. Before repository edits, enter a task workspace unless already in an associated task or child workspace. Use `edit` or `write` for implementation changes. Wait for the cwd switch before repository tool calls.
7. Load the packaged `orchestration` skill through its advertised path before delegating. When orchestration is active, delegate the implementation steps below rather than executing them in the parent. Spawned workers follow their assignment and must not delegate.

Do not create workspaces for discussion, explanation, planning, or read-only research. If an expected workspace is missing, stop editing and inspect `workspace status`; do not fall back to the original checkout. Keep temporary probes and generated artifacts under `$TMPDIR`, outside the repository, and remove them when finished.

## Make the change

Follow existing patterns, preserve unrelated work, and avoid speculative abstractions, dependencies, options, or compatibility behavior.

Explain before proceeding if evidence requires changing an approved public interface, persisted data, dependency, security property, or architecture. If a blocking design decision appears, ask the user rather than silently changing direction.

For each independently verifiable change:

1. Inspect the affected flow, callers, failure paths, and tests.
2. Make the least complex complete edit.
3. Review it against `write-good-code`.
4. Add or update a behavior test when the project has a suitable location and the test would catch a regression.
5. Run the fastest check that could disprove the changed behavior, then broader checks required by affected consumers or contracts.
6. Use `debug` if a check fails.

Run implementation checks inside the associated workspace.

## Complete the task

Use `verify` before claiming completion. Report the changed result, evidence, unchecked behavior, and active workspace concisely.

Call `workspace integrate` after verification. In `ask` mode it requests confirmation; in `allowed` mode integration is pre-authorized. Wait for the cwd switch back to the origin checkout before further tool calls.
