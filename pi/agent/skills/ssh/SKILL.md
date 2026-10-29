---
name: ssh
description: >-
  Use when executing or monitoring work on an SSH-accessible remote machine
  while keeping authoritative code and agent workflows local, including Git-based
  code transfer and remote log or artifact inspection. Not for ordinary Git-over-SSH
  operations alone, SSH configuration troubleshooting, or entirely remote workspaces.
---

# SSH execution

Keep code edits, worktrees, and integration local. Use Git to deliver a specific
revision to the remote machine; use SSH through the existing bash tool to run work
and inspect results. No remote Pi installation or separate SSH tools are required.

## Establish the project boundary

Read project instructions for the host alias, remote checkout, data/environment/output
paths, Git transfer route, and job launcher. Keep these project facts in the project,
not this skill. Ask only for missing details that block the requested operation.

- Local code is authoritative. Fix source locally and transfer a new revision rather
  than patching the remote checkout. Ask before an exception that creates remote-only
  source changes.
- Datasets, remote environments, logs, and artifacts stay remote unless transfer is
  requested or covered by project instructions. Prefer keeping them outside the code
  checkout; respect existing layouts rather than relocating data automatically.
- Local read/write/edit tools still address local files. Inspect remote files with SSH
  commands; use SCP/SFTP for authorized transfers. Label results with their host.
- Local skills and workspace/subagent machinery remain local. Do not assume their
  filesystem protections or worktree isolation apply to the remote machine.

## Connect and execute

Use the configured SSH alias and existing key/SSH-agent authentication. Keep secrets
out of commands, prompts, and logs. Preserve host-key verification; stop for human
setup on unknown or changed keys or authentication prompts. Do not enable agent
forwarding or weaken SSH settings just to make a connection work.

For noninteractive commands, use batch mode and no pseudo-terminal by default:

```bash
ssh -T -o BatchMode=yes HOST 'cd /absolute/remote/path && COMMAND'
```

This is a template, not a literal command. Quote for both the local and remote shell:
expansions outside the quoted remote command happen locally. For multiline scripts,
a quoted heredoc to `ssh ... HOST 'bash -s'` avoids local expansion, if remote bash
is available. Set the remote directory and required environment explicitly for each
invocation; separate SSH commands do not retain `cd` or `export`. Connection
multiplexing does not make a persistent shell.

Use remote tools actually available there. Request the harness permissions required
for outbound SSH; an approved connection does not authorize arbitrary remote changes.
Remote commands run with the remote account's privileges, not the local filesystem
sandbox. Never fall back to local execution when SSH fails.

## Deliver code with Git

1. Identify the exact local commit to execute. Uncommitted edits are not transferred
   by Git. Follow the existing workspace/commit workflow; do not silently run an older
   commit as if it included the current edits.
2. Use the project-approved transfer route. A request to run remotely is not blanket
   permission to push to a shared repository, publish a branch, or change Git remotes.
   Ask if the route or publication scope is unresolved.
3. Inspect the remote checkout's status and active jobs before changing its revision.
   Stop on unexpected changes; do not reset, clean, stash, overwrite, or merge them
   away. Avoid changing a checkout used by a running job; use a separate run checkout
   when needed and authorized.
4. Transfer and select the intended commit without an implicit merge. Verify remote
   `git rev-parse HEAD` matches the requested commit before launching work. Record that
   hash with the run; Git does not supply remote datasets or environment dependencies.

## Run, observe, and recover

Use the project's scheduler or established job mechanism for work that must survive
an SSH disconnect. Do not invent a new launcher or install remote software unless
needed and authorized. Capture the host, revision, working directory, job identifier,
and log/output locations so later calls can inspect the same run.

Read bounded log excerpts first; inspect more when needed. Retrieve only relevant
artifacts. Remote storage is not a confidentiality boundary: anything read into tool
output can reach the model and session logs.

Distinguish command submission, a running job, and successful completion. Check the
actual job exit status and relevant outputs; a successful submission command alone
is not evidence that the work succeeded.

A timeout or dropped SSH connection does not prove the remote process stopped. Before
retrying a launch, check the recorded job and logs to avoid duplicate work. Cancel a
specific job through its launcher when requested; killing the local SSH client is
not reliable remote cancellation. If completion or cancellation cannot be verified,
report that uncertainty rather than assuming success.
