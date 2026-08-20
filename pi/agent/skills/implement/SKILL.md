---
name: implement
description: Use when the user explicitly asks to implement, fix, add, remove, refactor, apply, write code, or execute an approved plan or specification. Delivers the smallest complete change and verifies the result.
---

# Implement

Use this skill when the user explicitly asks for code or file changes.

## Before Editing

1. Identify the requested outcome and source of truth: the current conversation, an approved plan, or a specification.
2. If a referenced document is a draft, has blocking questions, or conflicts with the user's current request, resolve that before editing.
3. Inspect the current code and verify that the plan or specification still matches it. Explain any conflict that would change the agreed behavior or approach.
4. For bugs, test failures, or unexpected behavior, use the `debug` skill before changing code.
5. For code changes, use the `write-good-code` skill.
6. Use `todowrite` for non-trivial work with several distinct steps.
7. If the user asks for subagents, load `subagent-delegation` before using them.

## Execution

- Make the smallest complete change that satisfies the requested behavior and affected contracts.
- Follow existing project patterns and avoid unrelated cleanup.
- Respect unrelated worktree changes.
- Do not add speculative abstractions, dependencies, options, or compatibility behavior.
- Explain before proceeding if current evidence requires a change to an approved public interface, persisted data, dependency, security property, or architecture.
- Add or update a behavior test when a suitable test location exists and the test would catch regression of the requested behavior.

For each independently verifiable change:

1. Inspect the affected flow, callers, failure paths, and tests.
2. Make the least complex complete edit.
3. Review the edit against `write-good-code`.
4. Run the fastest check that could disprove the changed behavior.
5. Run broader checks required by affected consumers or contracts.
6. If a check fails, use `debug` rather than guessing.

If implementation reveals a blocking design decision, stop and ask rather than silently changing the agreed direction.

## Completion

Before claiming completion, use the `verify` skill and report only what fresh evidence proves.
