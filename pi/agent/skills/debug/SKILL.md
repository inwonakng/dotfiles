---
name: debug
description: Use for bugs, failing tests, build errors, regressions, unexpected behavior, performance problems, or when a previous fix did not work. Requires root-cause investigation before fixes.
---

# Debug

Use this skill before proposing or applying fixes for technical failures.

Adapted from Superpowers' systematic-debugging workflow.

## Iron Rule

No fixes before root-cause investigation.

Do not patch symptoms because a fix seems obvious. First prove what is happening and why.

## Phase 1: Reproduce and Read Evidence

- Read the complete error message, stack trace, logs, or failing assertion.
- Identify exact reproduction steps or the exact command that fails.
- If the failure is not reproducible, gather more evidence before changing code.
- Check relevant recent changes when useful (`git diff`, nearby edits, changed config).

## Phase 2: Trace the Root Cause

- Trace bad values or behavior backward to where they originate.
- In multi-component flows, inspect each boundary:
  - input entering the component
  - output leaving the component
  - config/environment passed across the boundary
  - state changes at each layer
- Find a similar working example in the codebase and compare behavior.
- List meaningful differences. Do not dismiss differences without evidence.

Use `defer_task` with `accessMode: "readonly"` for bounded independent investigation when a fresh context would help.

## Phase 3: Form and Test One Hypothesis

State the hypothesis clearly:

```text
I think the root cause is X because Y.
```

Then test it with the smallest possible probe. Change only one variable at a time.

If the hypothesis fails, form a new one from the new evidence. Do not stack speculative fixes.

If three fix attempts fail or each fix reveals a new architectural problem, stop and discuss whether the underlying design is wrong.

## Phase 4: Fix the Cause

Only after the root cause is identified:

1. Add or identify a failing test/reproduction when practical and meaningful.
2. Implement one focused fix at the source of the problem.
3. Verify the original symptom is fixed.
4. Verify relevant regressions did not appear.

If a test would be trivial or impossible in the current project, state the manual or command-based verification instead.

## Red Flags

Stop and return to evidence gathering if you notice yourself thinking:

- "Just try this."
- "This is probably it."
- "I'll clean this up while I'm here."
- "The test should pass now" without running it.
- "One more quick fix" after prior attempts failed.

## Report Shape

When reporting a debug result, include:

- Symptom observed
- Root cause
- Evidence
- Fix applied or proposed
- Verification performed
