---
name: subagent-delegation
description: Use before delegating a bounded research, planning, implementation, review, or verification task to a Pi subagent. Defines scope, access, joining, and main-agent responsibility.
---

# Subagent Delegation

Use this skill when the user asks for subagents or when another skill explicitly calls for delegation.

## When Delegation Helps

Delegate work that has a clear goal and can return a useful result without owning unresolved user or design decisions. Common uses are:

- codebase or documentation research
- investigation of a specific failure or subsystem
- independent plan or code review
- verification of a named claim
- approved implementation with exact, non-overlapping file scope

Do not delegate tiny tasks, vague work, or overlapping write tasks.

## Access

Use `readonly` for research, planning, investigation, review, and verification.

Use `write` only when:

- the user approved implementation,
- the files or directory are exact,
- the required behavior and verification are clear, and
- the work does not overlap another writer.

## Brief

Every subagent brief must state:

- the goal
- relevant context and paths
- the task and permitted actions
- constraints and decisions it must not make
- required evidence or verification
- the expected return

Ask the subagent to return `DONE`, `BLOCKED`, or `NEEDS_CONTEXT`, followed by concise evidence, findings, changes, commands, and remaining uncertainty.

## Main-Agent Responsibility

The main agent must:

- keep user intent and unresolved decisions in the main conversation
- join background work before relying on it
- inspect and integrate returned work
- resolve conflicts and inconsistencies
- verify important claims directly
- report what remains unverified

A subagent's success report is not proof. Use the `verify` skill before completion claims.
