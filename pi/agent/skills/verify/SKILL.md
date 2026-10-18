---
name: verify
description: Use before claiming work is done, fixed, passing, reviewed, or ready. Requires fresh verification evidence and honest reporting of unverified parts.
---

# Verify

Make completion claims only after checking fresh evidence that proves them.

## Check the claim

Before reporting success:

1. Identify each behavior, build, test, and requirement-coverage claim.
2. Match each claim to a check:
   - Passing tests: run the named test command.
   - Successful build or typecheck: run the relevant command.
   - Fixed bug: rerun the original reproduction or regression check.
   - Working user-facing behavior: exercise the affected runtime flow when practical.
   - Met requirements: trace every requirement to implementation and evidence.
3. Run the fastest check capable of disproving the changed behavior.
4. Run broader checks required by affected contracts, such as shared-API consumers, exported types, migrations, or changed failure paths.
5. Read the full result, including warnings, skipped checks, failures, and exit status.
6. Limit the claim to what the result proves. State failures and unchecked behavior.

## Respect evidence limits

Tests cover only the cases executed. Builds and typechecks do not prove runtime behavior. Runtime checks cover only the observed flow and conditions. Inspection can establish wiring and requirement coverage, but not unexecuted behavior.

Inspect a subagent's diff or reproduce its evidence before relying on its report. A success statement alone is insufficient.

Do not rely on runs from before the last relevant edit, unrelated tests, predicted results, or lint for runtime claims. A targeted check is insufficient when a changed shared contract affects additional consumers.

## Report

Lead with the verified outcome, then give concise supporting commands or inspections and their results. State requested behavior or affected contracts that remain unchecked. Include a follow-up only when a concrete action remains.

Perform verification before writing the conclusion; the response should still put the conclusion first. Do not narrate the internal checklist or force empty report sections.
