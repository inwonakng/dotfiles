---
name: write-good-code
description: Use when planning, implementing, refactoring, fixing, or reviewing code. Enforces simple maintainable code -- avoid overengineering, follow existing patterns, use precise types, test observable behavior, and justify abstractions, dependencies, and public API changes.
---

# Write Good Code

Use this skill whenever code may be planned, changed, or reviewed.

## Core Rule

Write the smallest clear implementation that fully satisfies the current requirement and affected contracts.

Good code here is:

- correct for the requested behavior
- easy to read and change
- consistent with nearby code
- typed where the language and project support it
- verified by a check that observes the changed behavior when practical
- free of speculative abstractions, dependencies, compatibility layers, and unrelated cleanup

## Understand First

Simple code is not rushed code. Before choosing the smallest change, understand the affected flow, callers, contracts, and failure paths well enough to know where the change belongs.

For bug fixes, prefer the smallest root-cause fix at the shared boundary over repeated guards at individual call sites. If the task is a bug, follow the `debug` skill before editing.

## Simplicity Ladder

After understanding the affected flow, stop at the first rung that fully satisfies the requirement:

1. Does this need to exist at all? If the need is speculative, say so.
2. Is there already a helper, type, utility, convention, or pattern in this codebase?
3. Does the language standard library solve it?
4. Does the framework or platform already provide it?
5. Does an already-installed dependency solve it?
6. Can direct code solve it more clearly than a new abstraction, option, config, or interface?
7. Only then add new machinery.

The ladder shortens the solution, not the investigation. A small change in the wrong place is not simple; it is a hidden bug.

## Avoid Overengineering

Do not add without current evidence:

- an interface with one implementation
- a factory with one product
- a configuration option for a value that does not currently vary
- a compatibility layer for callers or versions that do not exist
- a new dependency for behavior the standard library, platform, or a few clear lines can provide
- a generic abstraction extracted from only one use case
- scaffolding for a possible future feature

If a plan or patch introduces new abstraction, dependency, public API, compatibility behavior, or file/module boundary, state the current requirement or inspected evidence that makes it necessary.

## Python Defaults

For Python code:

- add precise type annotations for new or changed functions, methods, and public module-level values
- annotate return types explicitly
- prefer concrete types over `Any`
- use `Any` only at dynamic or external boundaries, and narrow it as soon as practical
- choose collection abstractions such as `Mapping`, `Sequence`, or `Iterable` only when they reflect the actual accepted contract
- avoid introducing protocols, generics, decorators, metaclasses, or class hierarchies unless current callers require them
- preserve the existing project typing style when it is already consistent
- run the available type checker, linter, or formatter when configured and relevant

## Tests and Checks

Tests or checks should fail if the changed behavior regresses. Prefer assertions on observable behavior over implementation details or mock interactions.

Add or update a test when the project has a suitable test location and the change affects behavior. If a focused automated test is not practical, run the smallest useful command or inspection and report what remains unverified.

## Do Not Simplify Away

Never remove or skip:

- validation at trust boundaries
- error handling that prevents data loss, corrupt state, or silent failure
- security checks
- accessibility basics in user interfaces
- behavior checks for non-trivial logic when a suitable check exists
- requirements the user explicitly approved

## Self-Review Gate

Before completing a plan, implementation, or review, check:

- Did I implement or recommend only the requested behavior?
- Did I add any abstraction, dependency, option, compatibility path, or public API that is not required now?
- Are names and types precise?
- Are errors handled intentionally through project conventions?
- Would the verification fail if the requested behavior regressed?
- Did I leave any type, lint, test, or runtime check unrun? If yes, report it.
