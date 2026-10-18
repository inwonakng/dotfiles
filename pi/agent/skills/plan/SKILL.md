---
name: plan
description: Use when the user asks for an implementation plan, requests a design or architecture decision before coding, or wants implementation approaches compared. Produces an evidence-based, actionable plan in the current conversation for review and approval. Do not use to implement changes, explain existing code without proposing a change, review an existing plan, or create a standalone handoff specification.
---

# Plan

Produce an actionable implementation approach from the requested outcome and repository evidence. Keep the plan in the conversation for approval; use `prepare-spec` for a standalone handoff.

## Boundaries

- Inspect relevant code and documentation without modifying files or starting implementation.
- Resolve repository facts through inspection. Ask only about intent, constraints, or tradeoffs that cannot be discovered and would materially change the approach.
- Use `write-good-code` for code-related plans.
- Keep synthesis and unresolved user decisions in the main session. Subagents may gather bounded evidence or critique a draft.

## Develop the plan

1. Identify the observable outcome, success criteria, constraints, exclusions, and decisions already made. Resolve intent that blocks a sound approach.
2. Trace current behavior through callers, data flow, interfaces, configuration, and failure paths. Find nearby implementation and testing patterns. Identify contracts to preserve or deliberately change.
3. Choose the smallest complete approach supported by the evidence. Include deciding tradeoffs; present alternatives only when they materially differ in behavior, cost, complexity, compatibility, or risk.
4. Order the work into coherent implementation slices. Give each slice an outcome, likely paths or symbols, affected contracts, dependencies, and relevant verification. Avoid file inventories and speculative pseudocode.
5. Check every success criterion and ensure verification observes the requested behavior. Account for relevant migrations, security, compatibility, rollout constraints, and uncertainty.

## Present the plan

Lead with the proposed approach and outcome. Include current behavior only where it explains a constraint or decision, then give the implementation steps and verification. Add risks and open questions only when relevant.

Use the detail the task needs. Do not force a template, repeat the outcome in each section, or describe the planning process.

Resolve blocking questions before presenting a final plan. State non-blocking uncertainty, then stop for approval or revision.
