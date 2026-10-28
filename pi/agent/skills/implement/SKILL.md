---
name: implement
description: Use when carrying out an explicitly requested or approved change to code, configuration, documents, user data, or external state. Owns execution and verification, not coding style. Do not use for discussion, read-only diagnosis, planning, or explanation alone.
---

# Implement

Deliver the smallest complete change that satisfies the approved outcome. Implementation is not limited to programming.

## Execute the change

1. Establish the requested outcome from the conversation, approved plan, or specification. Resolve only questions that block the change; do not reopen settled decisions.
2. Inspect the immediate target and any assumptions that could invalidate the approach. Extend inspection to callers, contracts, or other components only when the change could affect them.
3. Make the change using applicable domain guidance. For code, apply `programming`; for unexplained or recurring failures, use `debug`. A clear typo or understood failure does not require a separate diagnosis phase.
4. Check the result against the approved outcome and inspect the diff or resulting state for unintended changes.

Tool permissions, workspaces, task tracking, and delegation follow the environment's instructions; they are not separate procedures defined by this skill.

## Verify the result

Choose the fastest check capable of detecting a wrong result. For a bug fix, check the original symptom. For user-facing behavior, exercise the affected flow when practical. Broaden checks when shared contracts or consequences require coverage beyond the immediate target.

Use relevant results obtained after the last change; do not rerun checks merely to enter a completion stage. Read outcomes, warnings, skipped checks, and exit status. For delegated work, inspect the contribution and its evidence rather than relying on a success statement alone.

When a check cannot run, use the available inspection or manual evidence and state its limits. A build or typecheck does not prove runtime behavior. Once the requested outcome is supported and relevant checks are complete, finish without unrelated cleanup or extra investigation.

Report the changed result, supporting checks, and important unchecked behavior concisely.
