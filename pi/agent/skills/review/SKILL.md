---
name: review
description: Use when reviewing a plan, diff, implementation, branch, or completed task. Checks requirements, correctness, maintainability, test quality, and risks before work is considered done.
---

# Review

Use this skill to review work with fresh, evidence-based judgment.

Use Pi's `spawn` / `spawn_control` when an independent context would reduce author bias or keep a large diff out of the main conversation.

## When to Review

Review is especially useful:

- after changing a shared or public interface
- after changing security, persisted data, concurrency, or multiple subsystems
- before claiming a feature is complete
- before merging or handing work back
- when a spawned implementer changed files

## Review Modes

### Inline review

Use this when the diff is small or the answer is conceptual.

1. Read the requirements or plan.
2. Inspect the changed files and affected contracts.
3. Check requirement coverage before code quality.
4. Identify findings by severity.
5. Recommend fixes or approval.

### Spawned review

Use `spawn` with `accessMode: "readonly"` and role `reviewer` when fresh context would help. Join the spawned reviewer before relying on its findings.

Give the reviewer a scoped brief that names:

- the requirements or plan being checked
- the exact files or diff command to inspect
- the contracts or failure modes affected
- verification already performed
- the required output format

Do not paste huge diffs into the main context if a file artifact or git command is enough.

## Severity Levels

- **Critical**: incorrect behavior, data loss, security issue, broken build, or violation of an explicit requirement. Must fix before proceeding.
- **Important**: likely bug, missing regression coverage for changed behavior, or a design issue likely to cause near-term failures or rework. Should fix before proceeding.
- **Minor**: cleanup, clarity, naming, optional refactor. Track or fix if cheap.
- **Question**: ambiguity requiring user or implementer decision.

## Review Checklist

### Pass 1: Requirement Coverage

- Trace each requested behavior to the code that implements it.
- Trace each changed behavior to evidence that would detect a regression.
- Check affected callers, public interfaces, configuration, persisted data, and user-visible flows.
- Confirm any deviation from the approved plan was explained before implementation.

### Pass 2: Engineering Quality

- Does the implementation address the cause or core requirement rather than only the visible symptom?
- Are failure and boundary cases handled and surfaced through project conventions?
- Would the tests fail if the changed requirement regressed, or do they only assert implementation details?
- Is this the least complex design that fully preserves required behavior, affected contracts, and error handling?
- Does it follow existing project patterns without adding speculative compatibility or unrelated cleanup?

## Output Shape

```markdown
## Review result

Status: APPROVED | APPROVED_WITH_MINOR_NOTES | CHANGES_REQUESTED | BLOCKED

### Findings
- [Severity] file:line — issue and why it matters

### Evidence checked
- files and diffs inspected

### Commands run
- command and result, if any

### Recommendation
```

Do not claim approval unless you inspected the relevant evidence.
