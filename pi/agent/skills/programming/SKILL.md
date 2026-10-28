---
name: programming
description: Use when writing, designing, refactoring, or reviewing code. Provides code-quality preferences for structure, types, dependencies, error handling, and behavioral tests. Not needed for prose, ordinary configuration edits, or general execution mechanics.
---

# Programming

Write clear code for the current requirement, following nearby project conventions. This skill supplies code-quality guidance, not another execution workflow.

## Structure and dependencies

- Prefer a suitable existing facility; otherwise write direct code. Do not introduce abstractions, options, dependencies, or compatibility paths for hypothetical future requirements.
- Add an interface, factory, generic mechanism, or new module boundary only when current callers or requirements justify it. Do not force a small change through a sequence of alternative designs.
- Use precise names and preserve the project's error-handling conventions. Correct a shared cause rather than duplicating guards at call sites when the evidence supports that location.
- Preserve trust-boundary validation, security checks, error handling that prevents data loss or silent failure, and accessibility requirements. Avoid defensive branches for states the contract rules out.

## Python preferences

- Add precise annotations to new or changed functions, methods, and public module-level values, including explicit return types. Preserve a consistent existing typing style.
- Prefer concrete types. Restrict `Any` to dynamic or external boundaries and narrow it as soon as practical.
- Use `Mapping`, `Sequence`, or `Iterable` only when they reflect the accepted contract.
- Add protocols, generics, decorators, metaclasses, or class hierarchies only when the current design requires them.

## Behavioral checks

Prefer assertions on observable behavior over implementation details or mock interactions. Add or update a regression test when behavior changes and the project supports tests; respect project-specific restrictions. Use configured type, lint, and formatting checks where relevant. General verification and completion reporting belong to the execution workflow.
