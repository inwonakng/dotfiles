---
name: skill-authoring
description: Use when creating, editing, refactoring, or evaluating SKILL.md files or reusable agent workflow prompts. Produces precise triggers, lean instructions, progressive disclosure, and evidence scaled to the behavioral impact of the change.
---

# Skill Authoring

Use this skill to change reusable agent behavior deliberately without turning every wording edit into a large evaluation project.

## Core Rule

Do not treat plausible wording as proof that a skill works. Match the verification effort to the impact of the change and state what was not behaviorally tested.

## 1. Classify the Change

Choose the evaluation depth before editing:

- **Structural:** spelling, formatting, broken links, or frontmatter corrections with no intended behavior change. Validate structure and references.
- **Behavioral:** instructions or examples intended to change decisions, actions, or output. Compare the previous version with the candidate on representative prompts.
- **High impact:** new global/shared skills, trigger-description changes, discipline rules, or workflows that can edit files or perform side effects. Use repeated runs, near-miss prompts, and held-out validation prompts.

If a proposed behavioral rule addresses only a hypothetical failure, first confirm that the previous version or no-skill baseline exhibits that failure.

## 2. Define the Behavior Contract

Record:

- **Trigger:** user intent or task conditions that should load the skill
- **Near miss:** similar tasks that should not load it
- **Baseline failure:** observable behavior that needs to change
- **Desired behavior:** observable replacement
- **Assertions:** checks that distinguish success from a plausible-looking response

Use concrete assertions. "Names the failing command and exit status" is testable. "Provides a robust analysis" is not.

## 3. Write the Smallest Useful Skill

### Description

The description carries the trigger decision. It should:

- start with `Use when...`
- describe user intent and observable task conditions
- distinguish the skill from adjacent skills
- stay below the 1024-character limit

### Body

Include only what the agent is likely to get wrong without the skill:

- a default procedure
- decision criteria tied to observable conditions
- non-obvious project or tool facts
- failure modes observed in baseline runs
- an output template when format matters
- a validation loop when the work can be checked

Explain why when the reason helps the agent handle cases not shown in the skill. Prefer a positive procedure or template over a list of prohibitions. Use prohibitions and rationalization checks only when the observed failure is knowingly skipping a rule under pressure.

Keep `SKILL.md` below 500 lines and preferably much shorter. Move detailed references, templates, or reusable scripts into `references/`, `assets/`, or `scripts/`. State when each referenced file should be loaded.

Prefer a script, hook, schema, or validator for mechanical invariants.

## 4. Evaluate Triggering

For a new skill or changed description:

1. Create should-trigger prompts with varied wording and detail.
2. Create close should-not-trigger prompts that expose an over-broad description.
3. Run the baseline and candidate in clean contexts.
4. Record whether each version loaded the skill.
5. For high-impact changes, run each prompt at least three times and keep some prompts out of the revision loop.
6. Revise based on categories of misses rather than copying phrases from the eval prompts.

## 5. Evaluate Output

For a behavioral change:

1. Run the same representative tasks against the baseline and candidate.
2. Grade each assertion with evidence from output, tool calls, or artifacts.
3. Inspect traces for ignored steps, wasted work, or new unintended behavior.
4. Revise and rerun when the candidate is inconsistent or regresses a required assertion.

For high-impact changes, add boundary or pressure cases and compare repeated results. Record time or token cost only when overhead is part of the decision. Use blind comparison only for qualities that cannot be graded mechanically, such as organization or clarity.

If behavioral evaluation cannot be run, report the skill as structurally validated and behaviorally unverified. Do not claim the wording improves behavior.

## 6. Validate the Package

Check:

- directory name matches `name`
- `name` uses lowercase letters, numbers, and hyphens and is at most 64 characters
- `description` exists, states when to use the skill, and is at most 1024 characters
- YAML frontmatter parses
- relative links resolve from the skill directory
- referenced resources exist and have a stated load condition
- the skill does not duplicate policy owned by the system prompt, global instructions, or another skill
- behavior-changing claims have evidence at the selected evaluation depth

Use an Agent Skills validator when available. Structural validation does not substitute for behavioral evaluation.

## Report

When skill authoring is the primary deliverable, state:

- **Change:** files and intended behavior changed
- **Evaluation depth:** structural, behavioral, or high impact
- **Evidence:** assertions and observed comparison results
- **Not verified:** skipped prompts, models, harnesses, or runtime conditions

Otherwise, include these facts under the primary workflow's output format.
