---
name: review
description: >-
  Use for an explicitly requested review of a plan, diff, implementation, or branch, or a focused risk-driven review of consequential changes such as security, persisted data, concurrency, or shared interfaces. Not a mandatory phase for every completed edit.
---

# Review

Judge the work against its requested behavior and available evidence. An ordinary implementation self-check does not require this separate workflow.

## Inspect the relevant risks

- Establish the review scope and requirements. Inspect the plan or changed files and follow affected contracts only as far as needed to assess a concrete risk.
- Check whether the work satisfies the requirements, introduces unintended behavior, or departs from approved decisions.
- Evaluate whether checks could detect the important regressions. Reuse applicable results; run additional checks when evidence is missing or stale.
- For code quality, apply `programming` principles rather than repeating a separate style checklist. Do not invent optional refactors to fill a review.

Use independent review when it would reduce author bias on consequential work or bound a large review. Delegation follows the environment's orchestration rules; it is not required merely because work is nearing completion.

## Report findings

Lead with consequential findings. Give severity, the location (such as `file:line`), the issue, and its consequence. Distinguish confirmed problems from questions.

- Critical: a severe correctness, security, data-loss, or build failure that blocks proceeding.
- Important: a likely bug, requirement gap, or missing check with a concrete failure risk.
- Minor: an optional clarity or maintainability improvement.

If there are no findings, say so without inventing them. Include concise evidence and important unverified behavior. Use a formal approval status only when the workflow requests one. A review request alone does not authorize edits.
