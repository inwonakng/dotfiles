---
name: review
description: Use when reviewing a plan, diff, implementation, branch, or completed task. Checks requirements, correctness, maintainability, test quality, and risks before work is considered done.
---

# Review

Use this skill to review work with fresh, evidence-based judgment.

Use Pi's `spawn` / `spawn_control` as the preferred fresh-context reviewer when useful.

## When to Review

Review is especially useful:

- after completing a non-trivial task
- before claiming a feature is complete
- before merging or handing work back
- when a plan or implementation feels risky
- when a spawned implementer changed files

## Review Modes

### Inline review

Use this when the diff is small or the answer is conceptual.

1. Read the requirements or plan.
2. Inspect the relevant files/diff.
3. Identify findings by severity.
4. Recommend fixes or approval.

### Spawned review

Use `spawn` with `accessMode: "readonly"` and role `reviewer` when fresh context would help. Join the spawned reviewer before relying on its findings.

Give the reviewer a bounded brief:

- what changed or what plan is being reviewed
- where to find the plan/spec, if any
- exact files or diff command to inspect
- what risks to focus on
- required output format

Do not paste huge diffs into the main context if a file artifact or git command is enough.

## Severity Levels

- **Critical**: incorrect behavior, data loss, security issue, broken build, or violation of an explicit requirement. Must fix before proceeding.
- **Important**: likely bug, missing meaningful test, maintainability issue that will cause near-term problems. Should fix before proceeding.
- **Minor**: cleanup, clarity, naming, optional refactor. Track or fix if cheap.
- **Question**: ambiguity requiring user or implementer decision.

## Review Checklist

Check:

- Does the work satisfy the user's explicit requirements?
- Does it follow the approved plan, or are deviations explained?
- Are edge cases handled where relevant?
- Are errors surfaced clearly?
- Are tests meaningful rather than superficial?
- Is the implementation simpler than the alternatives?
- Does it respect existing project patterns?
- Are unrelated files or behaviors changed?

## Output Shape

```markdown
## Review result

Status: APPROVED | APPROVED_WITH_MINOR_NOTES | CHANGES_REQUESTED | BLOCKED

### Findings
- [Severity] file:line — issue and why it matters

### Evidence checked
- files/diffs inspected
- commands run, if any

### Recommendation
```

Do not claim approval unless you inspected the relevant evidence.
