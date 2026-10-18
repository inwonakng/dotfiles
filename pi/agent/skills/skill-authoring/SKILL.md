---
name: skill-authoring
description: Use when creating, editing, refactoring, or evaluating SKILL.md files or reusable agent workflow prompts. Produces precise triggers, lean instructions, progressive disclosure, and evidence scaled to the behavioral impact of the change.
---

# Skill authoring

Match verification to the change's impact. Plausible wording is not evidence that a skill works.

## Classify the change

Choose the evaluation depth before editing:

- Structural: spelling, formatting, links, or frontmatter corrections with no intended behavior change. Validate structure and references.
- Behavioral: instructions or examples that change decisions, actions, or output. Compare the previous version and candidate on representative prompts.
- High impact: new global/shared skills, changed trigger descriptions, discipline rules, or workflows with file edits or other side effects. Use repeated runs, near-miss prompts, and held-out validation prompts.

For a rule addressing a hypothetical failure, first confirm that the previous version or no-skill baseline exhibits it.

## Define the behavior

Identify the conditions that should load the skill, similar tasks that should not, the observed baseline failure, the desired replacement, and assertions that distinguish success from a plausible response. Keep these as working criteria unless the user requests an evaluation document.

Use observable assertions, such as "names the failing command and exit status." When revising an existing skill, preserve its trigger, required steps, safety boundaries, and exceptions unless the user requested a behavior change.

## Write the skill

Start the description with `Use when...`. Describe user intent and observable conditions, distinguish adjacent skills, and keep it below 1024 characters.

Include only instructions the agent needs to avoid likely mistakes:

- the default procedure and decision criteria
- non-obvious project or tool facts
- failures observed in baseline runs
- an output format when the task requires one
- a validation loop when the result can be checked

Follow `how-to-communicate` for wording. Use direct instructions and sentence-case headings. Remove repeated rules, preambles, and recaps. Keep internal checks internal; require user-facing explanation only when it supports a decision, required evidence, or a requested deliverable. Output formats should allow concise answers without forcing empty sections or process narration.

Explain a rule when the reason helps with unfamiliar cases. Prefer a procedure or template over prohibitions. Use prohibitions and checks for rationalization when the observed failure is knowingly skipping a rule under pressure.

Keep `SKILL.md` below 500 lines and preferably much shorter. Move detailed references, templates, and reusable scripts into `references/`, `assets/`, or `scripts/`, with an explicit load condition for each resource. Prefer scripts, hooks, schemas, or validators for mechanical invariants.

## Evaluate triggering

For a new skill or changed description:

1. Create varied prompts that should trigger it and close near misses that should not.
2. Run the baseline and candidate in clean contexts and record whether each loaded the skill.
3. For high-impact changes, run each prompt at least three times and keep some prompts out of the revision loop.
4. Revise for categories of misses rather than copying evaluation phrasing into the skill.

## Evaluate output

For behavioral changes:

1. Run the same representative tasks against the baseline and candidate.
2. Grade each assertion using output, tool calls, or artifacts.
3. Inspect traces for skipped steps, wasted work, and unintended behavior.
4. Revise and rerun if the candidate is inconsistent or regresses a required assertion.

For high-impact changes, add boundary or pressure cases and compare repeated results. Measure time or tokens only when overhead affects the decision. Use blind comparison for qualities that cannot be graded mechanically, such as clarity.

If behavioral evaluation cannot be run, report structural validation separately and leave behavior explicitly unverified. Do not claim wording improves behavior without comparison evidence.

## Validate the package

Check that:

- the directory matches `name`, which uses lowercase letters, numbers, and hyphens and is at most 64 characters
- `description` states when to use the skill and is at most 1024 characters
- YAML frontmatter parses
- relative links resolve from the skill directory
- referenced resources exist and have load conditions
- policy owned by system instructions, global instructions, or another skill is not duplicated
- behavior-change claims have evidence at the selected evaluation depth

Use an Agent Skills validator when available. Structural checks do not establish behavioral effectiveness.

## Report

Lead with the changed files and intended effect. State the evaluation depth, evidence, and anything behaviorally unverified, including skipped prompts, models, or runtime conditions. Fit this into the primary task's response format when skill authoring is only part of the work. Do not turn the report into an evaluation diary.
