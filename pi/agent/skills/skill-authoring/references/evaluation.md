# Behavioral evaluation

Use this procedure for safety-sensitive or broadly deployed workflow changes, or inconsistent results that need a deeper comparison.

1. Choose representative tasks and observable assertions from the observed failure and required behavior. Include boundary cases and close non-triggering prompts when selection changes.
2. Run the same tasks with the baseline and candidate in clean contexts, using the intended model and runtime. Record outputs, tool calls, and resulting artifacts.
3. Repeat cases enough to distinguish a consistent effect from run-to-run variation. Keep some prompts outside the revision loop to check whether the instructions generalize.
4. Check required behavior and safety boundaries, not just plausible output. Inspect traces for skipped steps, repeated reads, wasted work, and unintended actions.
5. Revise for categories of failure and rerun affected cases. Use blind comparison for subjective writing quality when useful.

When reducing overhead, compare unnecessary tool calls, repeated skill reads, time to the first useful action, and total time or tokens alongside correctness. Fewer calls are not an improvement if they omit necessary evidence or checks.

Report which models, cases, and runtime conditions were evaluated and which were not. Do not generalize structural checks or a single favorable run into a claim of reliable behavioral improvement.
