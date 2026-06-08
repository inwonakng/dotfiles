---
description: Write one or more implementation plan files from the current planning discussion
agent: docs
subtask: false
---

Materialize the current planning discussion into one or more implementation plan files under `plans/`.

Use the current conversation as the source of truth. If `$ARGUMENTS` is provided, treat it as additional guidance, not as a replacement for decisions already made.

Do not implement code. Do not modify source files.

Before writing anything, decide whether the implementation plan is ready to materialize. If there are unresolved decisions, missing requirements, ambiguous decomposition, or open questions that would affect the implementation plan, ask the user directly in this conversation and do not create or update files yet.

Only write plan files once the needed decisions are resolved. A generated implementation plan must be actionable and resolved. It should include the goal, relevant context, constraints, non-goals, implementation steps, and verification steps.

Do not write unresolved questions, TBDs, placeholders, or speculative decisions into a plan file unless the user explicitly asks for a brainstorming note or decision log instead of an implementation plan.
