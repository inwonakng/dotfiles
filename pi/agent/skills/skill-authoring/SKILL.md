---
name: skill-authoring
description: >-
  Use when creating, editing, or evaluating SKILL.md files or reusable agent workflow prompts. Covers trigger boundaries, concise instructions, and evaluation proportionate to behavioral risk; not general editing mechanics.
---

# Skill authoring

Add instructions that address observed failures or supply context the model lacks. Plausible wording alone does not establish better behavior.

## Define the responsibility

Identify when the skill should load, nearby tasks that should not load it, the observed problem, and the intended replacement behavior. Preserve unrelated requirements and safety boundaries. Keep these as working criteria unless the user requests an evaluation document.

Give each rule one authoritative home: global behavior in global instructions, tool mechanics in tool instructions, project facts in project instructions, and specialized guidance in the skill. Avoid chains of mandatory skill reads for routine tasks.

## Write minimal guidance

- Describe the purpose and observable trigger in frontmatter, including important exclusions. Use a clear `Use when...` description, no longer than 1024 characters.
- Include only useful decision criteria, non-obvious facts, and steps needed to avoid likely mistakes. Make expensive investigation conditional and give it a stopping condition.
- Use direct instructions and sentence-case headings. Prefer positive procedures over long prohibition lists. Explain a rule when its reason helps with unfamiliar cases.
- Keep checks internal unless the user needs evidence or a decision. Let output formats omit irrelevant sections.
- Keep `SKILL.md` short and below 500 lines. Put detailed references or reusable resources in separate files with explicit load conditions; do not split a short skill just to create more reads.

## Evaluate proportionately

For structural changes, check frontmatter and references. For ordinary personal workflow revisions, inspect the changed instructions and try representative tasks where practical, including a near miss when a trigger changes. Compare against the previous behavior or an observed failure before claiming improvement.

Use repeated baseline/candidate runs and held-out prompts for safety-sensitive or broadly deployed changes, or when results are inconsistent. Read [the evaluation procedure](references/evaluation.md) only for that deeper comparison, not for every wording revision.

If behavioral evaluation is unavailable, keep the revision reviewable and report behavior as unverified rather than blocking all useful edits or claiming success from wording alone.

## Validate and report

Check that frontmatter parses, the name matches the directory and uses lowercase letters/numbers/hyphens within 64 characters, descriptions fit their limit, and referenced resources exist. Check for duplicated policies and stale skill references.

Report changed files, intended effect, checks performed, and behavioral uncertainty concisely. Structural validation does not prove better triggering, lower tool use, or improved task outcomes.
