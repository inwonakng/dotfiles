---
name: plan
description: Use when the user requests an implementation plan, a design decision before coding, or a comparison of approaches. Chooses an actionable approach for approval. Not needed just to execute a small understood change. Do not use for explanation alone, review of an existing plan, or a standalone handoff specification.
---

# Plan

Choose the smallest complete approach supported by the requested outcome and available evidence. Keep the plan in the conversation; do not start implementation.

## Decide the approach

1. Reuse agreed outcomes, constraints, and decisions. Ask about intent or tradeoffs only when they materially change the approach and cannot be resolved from available evidence.
2. Inspect only repository facts that could change the recommendation. Follow callers, data flow, interfaces, configuration, or failure paths when the proposed change makes them relevant, not as a mandatory inventory.
3. Choose an approach and explain deciding tradeoffs. Compare alternatives only when they materially differ in behavior, cost, complexity, or risk. Apply `programming` principles to code designs without starting an implementation workflow.
4. Identify the implementation steps and how the requested outcome will be checked. Add paths, ordering, affected contracts, migrations, or rollout considerations only where they prevent ambiguity or address a concrete risk.

Stop investigating when the approach is actionable and further inspection would not change it. State non-blocking uncertainty; resolve blockers before calling the plan final.

## Present the plan

Lead with the recommendation, then give steps and verification at the level the task needs. Do not force a template or repeat the outcome across sections. Stop for approval or revision. Use `prepare-spec` only when the requested deliverable is a durable handoff.
