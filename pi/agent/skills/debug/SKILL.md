---
name: debug
description: Use when diagnosing unexplained failures, regressions, unexpected behavior, performance problems, or a fix that did not work. Do not use for a clear typo or a change whose cause is already established; those can proceed directly to implementation.
---

# Debug

Find an evidence-supported cause before applying a fix. A hypothesis guides investigation; it is not itself proof.

## Diagnose the symptom

1. Use the reported error, logs, failing assertion, or observed behavior to identify the symptom and a likely cause. Reuse evidence already available.
2. Inspect or probe the smallest relevant path to distinguish that cause from plausible alternatives. Reproduce the failure when practical; existing logs and clear code or configuration evidence may establish the cause when local reproduction is unavailable.
3. If the evidence does not explain the symptom, expand the investigation where the uncertainty points: a relevant boundary, recent change, or working example. Do not trace every boundary or account for unrelated differences by default.
4. Stop investigating when the evidence explains the symptom and identifies an appropriate fix or a concrete blocker.

Use focused probes, changing one variable at a time where practical. A failed hypothesis should update the next probe, not lead to stacked speculative fixes. If three fix attempts fail, or successive attempts reveal architectural problems, stop and discuss the approach with the user.

## Hand off the diagnosis

For diagnosis-only requests, report the cause, supporting evidence, and any remaining uncertainty without applying changes.

When a fix is authorized, carry the causal finding and a check for the original symptom into implementation. Prefer correcting the source over hiding the symptom. If reproduction or verification is unavailable, distinguish the supported diagnosis from behavior that remains unverified.
