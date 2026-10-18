---
name: write-good-code
description: Use when planning, implementing, refactoring, fixing, or reviewing code. Enforces simple maintainable code -- avoid overengineering, follow existing patterns, use precise types, test observable behavior, and justify abstractions, dependencies, and public API changes.
---

# Write good code

Write the smallest clear implementation that fully satisfies the current requirement and affected contracts. Follow nearby patterns, use types where supported, and check observable behavior.

## Understand the affected flow

Inspect callers, contracts, and failure paths before choosing where to change code. For bugs, use `debug` first and prefer a root-cause fix at the shared boundary over repeated guards at call sites.

## Choose the simplest complete solution

Stop at the first option that meets the requirement:

1. Omit behavior with no current need; identify speculative requirements.
2. Reuse an existing helper, type, utility, convention, or pattern.
3. Use the standard library.
4. Use the framework or platform.
5. Use an installed dependency.
6. Write direct code when clearer than a new abstraction, option, configuration, or interface.
7. Add new machinery only when the earlier options are insufficient.

Investigate enough to place the change correctly. A small edit in the wrong place can leave the cause unresolved.

Require current evidence before adding an interface with one implementation, a factory with one product, a fixed-value configuration option, unsupported compatibility behavior, or an abstraction for one use case. Avoid scaffolding for future features, unnecessary dependencies, and unrelated cleanup.

For a new abstraction, dependency, public API, compatibility behavior, or file/module boundary, identify the current requirement or inspected evidence that requires it. Explain material design choices when needed for approval; do not narrate routine choices.

## Python defaults

- Add precise annotations to new or changed functions, methods, and public module-level values, including explicit return types.
- Prefer concrete types. Restrict `Any` to dynamic or external boundaries and narrow it as soon as practical.
- Use `Mapping`, `Sequence`, or `Iterable` only when they reflect the accepted contract.
- Add protocols, generics, decorators, metaclasses, or class hierarchies only when current callers require them.
- Preserve a consistent existing typing style.
- Run configured type checks, lint, or formatting when relevant.

## Check behavior

Prefer assertions on observable behavior over implementation details or mock interactions. A check should fail if the requested behavior regresses.

Add or update a test when behavior changes and the project has a suitable test location. If a focused automated test is impractical, use the smallest useful command or inspection and report its limits.

Preserve trust-boundary validation, error handling that prevents data loss or silent failure, security checks, accessibility basics, applicable checks for non-trivial logic, and explicitly approved requirements.

## Review before finishing

Check internally that the work:

- covers only the requested behavior
- adds no unsupported abstraction, dependency, option, compatibility path, or API
- uses precise names and types
- handles errors through project conventions
- has verification capable of detecting a regression

Report relevant type, lint, test, or runtime checks left unrun.
