---
name: verify
description: Use before claiming work is done, fixed, passing, reviewed, or ready. Requires fresh verification evidence and honest reporting of unverified parts.
---

# Verify

Use this skill before any completion or success claim.

Adapted from Superpowers' verification-before-completion workflow.

## Iron Rule

No completion claims without fresh verification evidence.

Do not say work is done, fixed, passing, clean, or ready unless you have just checked the evidence that proves that claim.

## Verification Gate

Before claiming success:

1. **Identify** what would prove the claim.
   - Tests pass? Run the relevant test command.
   - Build succeeds? Run the build/typecheck command.
   - Bug fixed? Re-run the reproduction or regression check.
   - Requirement met? Check the requirement against the implementation.
2. **Run or inspect** the smallest relevant verification.
3. **Read the output** including failures, warnings, and exit status.
4. **Report honestly**:
   - If it passed, say what passed and include the command/evidence.
   - If it failed, say what failed and what remains.
   - If not run, say why and what was checked instead.

## What Counts

Good evidence:

- command output from this session
- inspected code paths tied to the requirement
- reproduced symptom before/after when practical
- reviewer report plus your own spot-check of the actual diff

Not enough:

- "should work"
- prior runs from before the edit
- relying only on a subagent's success statement
- tests unrelated to the changed behavior
- lint passing when the claim is that runtime behavior is fixed

## Regression Tests

When adding a meaningful regression test:

1. Confirm the test fails before the fix when practical.
2. Apply the fix.
3. Confirm the test passes.

If red/green verification is impractical, explain why.

## Final Response Shape

Include:

- Summary of changes or conclusion
- Verification run: `command` → result
- Not verified: anything relevant that remains unchecked
- Follow-up: only if there is a real next action

Avoid celebratory language before verification. Evidence first, then conclusion.
