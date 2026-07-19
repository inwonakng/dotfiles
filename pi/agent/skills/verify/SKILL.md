---
name: verify
description: Use before claiming work is done, fixed, passing, reviewed, or ready. Requires fresh verification evidence and honest reporting of unverified parts.
---

# Verify

Use this skill before any completion or success claim.

## Iron Rule

No completion claims without fresh verification evidence.

Do not say work is done, fixed, passing, clean, or ready unless you have just checked the evidence that proves that claim.

## Verification Gate

Before claiming success:

1. **List the claims.** Separate behavior, build, test, and requirement-coverage claims.
2. **Match each claim to proof.**
   - Tests pass: run the named test command.
   - Build succeeds: run the build or typecheck command.
   - Bug is fixed: re-run the original reproduction or regression check.
   - User-facing behavior works: exercise the affected runtime flow when practical.
   - Requirements are met: trace every requirement to implementation and evidence.
3. **Run the fastest check capable of falsifying the changed behavior.**
4. **Run broader checks required by the affected contract.** Examples include package tests for a shared API, build/typecheck for exported types, migration checks for persisted data, or failure-path checks for changed error behavior.
5. **Read the full result** including failures, warnings, skipped checks, and exit status.
6. **Report only what the evidence proves.** State failures and unchecked behavior explicitly.

## Evidence Boundaries

- Tests prove only the cases they execute.
- A build or typecheck proves compilation, not runtime behavior.
- A runtime check proves only the flow and conditions observed.
- Code inspection can prove wiring and requirement coverage, but not unexecuted runtime behavior.
- A reviewer or subagent report is a lead until you inspect the diff or reproduce its evidence.

Not enough:

- "should work"
- prior runs from before the last relevant edit
- relying only on a subagent's success statement
- tests unrelated to the changed behavior
- lint passing when the claim is that runtime behavior is fixed
- one targeted check when a changed shared contract has additional consumers

## Final Response Shape

Include:

- Conclusion: one sentence stating only the verified outcome
- Evidence: `command or inspection` → result and the claim it supports
- Not verified: each requested behavior or affected contract that remains unchecked
- Follow-up: only when a concrete next action remains

Avoid celebratory language before verification. Evidence first, then conclusion.
