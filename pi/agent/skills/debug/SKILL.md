---
name: debug
description: Use for bugs, failing tests, build errors, regressions, unexpected behavior, performance problems, or when a previous fix did not work. Requires root-cause investigation before fixes.
---

# Debug

Investigate the root cause before proposing or applying a fix. An obvious-looking patch still needs evidence.

## Reproduce the failure

- Read the complete error, stack trace, logs, or failing assertion.
- Identify the exact reproduction steps or failing command.
- If the failure cannot be reproduced, gather more evidence before changing code.
- Inspect relevant recent changes when useful.

## Trace the cause

Trace incorrect values or behavior back to their source. In multi-component flows, inspect inputs, outputs, configuration, environment, and state changes at each boundary.

Find a working example in the codebase and compare it with the failing path. Track each observed difference; dismiss one only with evidence that it cannot affect the failure. Gather evidence before forming hypotheses.

When orchestration is active, delegate investigation to readonly subagents. Otherwise, use one when a named component or path needs independent investigation. Follow the packaged `orchestration` skill through its advertised path, specify the evidence required, and join background work before relying on it. Spawned workers investigate their assignment directly and must not delegate.

## Test a hypothesis

Form a specific, evidence-backed hypothesis internally. Test it with the smallest probe, changing one variable at a time. If it fails, use the new evidence to form the next hypothesis rather than stacking speculative fixes.

If three fix attempts fail, or each reveals another architectural problem, stop and discuss the design with the user.

Return to evidence gathering when a proposed edit is a guess, unrelated cleanup, or another quick fix after failed attempts. A predicted passing test is not a result.

## Fix the cause

After identifying the root cause:

1. Add or identify a test or reproduction that fails for the observed symptom and would detect its return.
2. Apply a fix at the source.
3. Verify the original symptom and check affected callers and contracts.

When the project has no suitable test location or automation cannot reproduce the symptom, use manual or command-based verification and state its limits.

## Report

Lead with the fix or diagnosed cause. Include the observed symptom, supporting evidence, and verification without repeating the investigation. Distinguish proposed fixes from applied changes and state what remains unverified.
