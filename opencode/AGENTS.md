## Desired Behavior

- Never jump to conclusions. If the user says something like "can you implement me XXX.. by the way, will it be XYZ?" -- consider the **FULL CONTEXT** instead of just "doing" the task one by one (i.e. jump ahead to the implementation without answering the user's question).
- Prioritize answering the user's question first. Do not jump to what you think is relevant. 
- If the task is getting too complicated, you are probably over complicating it. Take a step back. think about the big picture and what the underlying problem is. Do not just apply short term fixes.

## General Coding practice

- no leading underscore unless it's actually private.
- if more than 3 params, always specify them as keyword arguments.
- never use `chmod`. assume scripts will be ran with the specific application binaries (e.g. bash or pixi run python).
  - in fact, never mess with file permissions. If you can't see it, there is a reason for it. ask the user.
- Avoid try/catch unless we absolutely need it. We want to see the errors.
  - use asserts instead. be proactive instead of reactive.
- Use python built-in typehints (i.e. don't use typing for primitive types) if applicable.
- NEVER manually edit dependencies. let the tool (`pixi` or `uv`) handle it.
- Whenever you update some existing code, search the project by that exact symbol name to update imports or check usage. Do not be lazy.
- Write clean code. think twice about implementations. Do not create a bunch of single-use utility functions. 

## Debugging

- never speculate anything about how the code behaves. Do not make statements like "this is a known issue in numpy". Always back up with online sources or actual code. If you can't find this, say you can't.
- If you think you found the bug, do not directly jump into fixing it. First double/triple check that we are correct by writing a simple script to reproduce it. Run this by the user before going forward to confirm the bug is correct.
