---
name: plan
description: Use when the user asks for an implementation plan, requests a design or architecture decision before coding, or wants implementation approaches compared. Produces an evidence-based, actionable plan in the current conversation for review and approval. Do not use to implement changes, explain existing code without proposing a change, review an existing plan, or create a standalone handoff specification.
---

# Plan

Planning turns a requested change and repository evidence into an agreed implementation approach. A useful plan explains:

- the observable outcome and success criteria
- how the relevant behavior works now
- the chosen approach and why it fits the repository
- the affected contracts and ordered implementation slices
- how the outcome will be verified

## Boundaries

- Do not modify files or begin implementation.
- Inspect the relevant code and documentation before planning.
- Resolve repository facts through inspection. Ask the user only about intent, constraints, or tradeoffs that cannot be discovered.
- Ask only questions whose answers could materially change the approach.
- Use `write-good-code` for code-related plans.
- Keep planning in the current conversation. Use `prepare-spec` when the deliverable must stand alone for another session or implementer.
- The main agent synthesizes and presents the plan. Subagents may gather bounded evidence or critique a draft, but they do not own unresolved user decisions.

## Workflow

1. **Frame the outcome**
   - Identify the requested behavior, success criteria, constraints, exclusions, and decisions the user has already made.
   - Ask about unresolved intent only when it blocks a sound approach.

2. **Understand the current system**
   - Trace the relevant behavior through its callers, data flow, interfaces, configuration, and failure paths.
   - Find nearby implementation and testing patterns.
   - Identify contracts that must remain stable or change deliberately.

3. **Choose the approach**
   - Select the smallest complete approach supported by repository evidence.
   - Explain the deciding tradeoffs.
   - Present alternatives only when they differ materially in behavior, cost, complexity, compatibility, or risk.

4. **Sequence the work**
   - Divide the change into ordered, coherent implementation slices.
   - For each slice, state its outcome, likely files or symbols, affected contracts, dependencies, and relevant verification.
   - Do not turn the plan into a file inventory or speculative pseudocode.

5. **Check completeness**
   - Ensure every success criterion is covered.
   - Ensure verification observes the requested behavior.
   - Identify migrations, compatibility concerns, security implications, rollout constraints, and meaningful uncertainty when relevant.

## Output

Use only the sections the task needs:

```markdown
# [Change]

## Outcome

## Current behavior and constraints

## Proposed approach

## Implementation steps

1. **[Coherent change]** — `paths` or `symbols`
   - Behavior and contract changes
   - Dependencies or ordering
   - Relevant verification

## Verification

## Risks and open questions
```

Blocking questions must be resolved before presenting a final plan. Keep non-blocking uncertainty explicit. After presenting the plan, stop for approval or revision.
