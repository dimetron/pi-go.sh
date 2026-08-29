+++
title = 'Subagents: fanning out work without losing the thread'
date = 2026-08-29T00:00:00+02:00
category = 'Deep dive'
description = 'pi-go subagent system dispatches typed roles — explore, plan, designer, reviewer, task — over the Agent Client Protocol, with worktree isolation and concurrency guardrails.'
lede = 'pi-go subagent system dispatches typed roles over ACP with worktree isolation and concurrency guardrails.'
+++

When a task is too big for one loop, pi-go spawns typed child agents — some in isolated git worktrees, some over the Agent Client Protocol — and orchestrates them with a bounded pool, retries, and clean cancellation so you never lose track of what's running.

## What a subagent actually is

A subagent is a separate process pi-go launches to do a focused job and report back. The main agent's tool loop can call a `subagent` tool with one of three modes — **single**, **parallel**, or **chain** — and the orchestrator handles the rest: it resolves the agent's role and model, acquires a pool slot, optionally creates a worktree, launches the process, and streams events back as JSONL.

Most subagents are just the `pi` binary re-launched in `--mode json` with a resolved model, a system prompt, and a positional task. The orchestrator finds its own executable with `os.Executable()` and runs `pi --mode json --model <role-model> --system <instruction> <prompt>`, then parses the child's stdout line by line into the same `Event` stream the TUI already understands. A few agents aren't pi at all — more on that under ACP below.

## The typed roles

Every agent is a markdown file with a YAML frontmatter block — `name`, `description`, `role`, `worktree`, `tools`, optional `timeout` and `lsp` — followed by a system-prompt body. pi-go discovers them from three places, in priority order: `.pi-go/agents/` in the nearest project ancestor (highest), `~/.pi-go/agents/` (user), and a set of **bundled** agents embedded into the binary via `go:embed`. Same-named entries override as they merge, so a project can shadow a bundled agent without forking it.

The bundled roster is opinionated. Each role is tuned to a different model tier and tool surface:

- **explore** — `role: smol`, read-only. Fast codebase research: find code, trace dependencies, map architecture. Frequently spawned several at once, each on a different angle.
- **plan** — `role: plan`, read-only. Analyze the codebase and produce a vertically-sliced implementation plan before code is written.
- **architect** — `role: slow`, read-only with git diff/hunk tools. Decide package boundaries, dependency direction, and whether a change fits; draw diagrams.
- **designer** — `role: slow`, `worktree: true`. Design and modify code in an isolated worktree, then hand off the patch.
- **task** — `role: default`, `worktree: true`, `timeout: 1800000`. Complete a coding task end-to-end in a worktree, including build and verify, then report changed files.
- **worker** — `role: default`, no worktree. A general-purpose worker for smaller in-place edits.
- **quick-task** — `role: smol`. Small focused tasks with minimal overhead: grep, read the lines you need, edit, verify.
- **code-reviewer** and **spec-reviewer** — `role: slow`, read-only. Find the two or three issues that matter, not a long list of every nit.
- **memory-compressor** — `role: smol`, no tools, short timeout. Turns raw tool observations into structured memory entries in the background.

A frontmatter `role` isn't a model name — it's a config key pi-go resolves (`smol`, `plan`, `slow`, `default`) to an actual provider model, so the same agent definition runs against whatever you have configured. An agent can also declare a restricted `tools:` list (empty means all tools) and an `lsp:` surface of `off`, `min`, or `full`, so the expensive language-server client is bought per agent that navigates code rather than by every session.

## The Agent Client Protocol bridge

Five bundled agents don't run pi at all. **claude**, **gemini**, **cursor**, **copilot**, and **agy** (Google Antigravity) launch their own CLI binary over the **Agent Client Protocol (ACP)** — a stdio JSON-RPC protocol for talking to an agent's runner. pi-go ships per-runner adapters under `internal/acp/client/` (`claudecode`, `gemini`, `cursor`, `copilot`, `agy`), each implementing a shared `acpSession` interface: `Events()`, `Done()`, `Cancel()`, `Wait()`.

A companion agent, **codex**, takes a different path: it spawns `codex app-server` and speaks OpenAI's direct JSON-RPC protocol rather than ACP. From the orchestrator's point of view the distinction is small — `dispatchSpawn` branches three ways:

```
switch {
case isACPAgent(agentName):    // claude, gemini, cursor, copilot, agy
    return dispatchACP(ctx, spawnOpts, agentName)
case isCodexAgent(agentName):  // codex, codex-review
    return dispatchCodex(ctx, spawnOpts, agentName)
default:                       // everyone else: child pi --mode json
    return o.spawner.Spawn(ctx, spawnOpts)
}
```

ACP agents run untethered from pi's own tool loop, so they need an explicit termination signal. The dispatcher wraps every ACP prompt in a preamble that tells the agent to reply with a literal `<Task Completed>`! sentinel when it's done — otherwise some agents just keep talking. The same preamble enforces anti-hallucination rules: before claiming completion the agent must run `git diff --name-only`, list the actual changed files, and never assert a build or test passes without pasting the real output. `pumpACPSession` strips the sentinel from the final text and tee's the event stream to the session's `acp.jsonl` alongside the native-pi subagent events, so the log shape is the same regardless of which protocol produced it.

One subtle point the code calls out: the orchestrator intentionally does *not* forward pi's resolved `--model` to ACP agents. A model id meaningful to pi (say `claude-haiku-4-5`) passed to `gemini --model` returns a 500 "Requested entity was not found" because each CLI has its own model namespace. Each ACP agent's own default model is the safe choice; if you need a specific Gemini model, set it in the gemini CLI's own config.

## Worktree isolation for the [worktree] agents

Agents marked `worktree: true` — **designer** and **task** — don't edit your working tree directly. Before launch, `resolveWorkDir` asks the `WorktreeManager` for a fresh git worktree on a generated branch, and the child runs with that path as its `--work-dir`. Their system prompts are explicit about this: edits are local to the worktree until the caller merges or reapplies them, and the agent must not claim changes have landed in the main tree. The final response is a handoff — changed files, per-file summaries, verification commands and results, and exact patch notes when the caller needs to transplant.

The worktree is created from the repo root the orchestrator was built with (empty disables worktrees entirely), and cleanup is deferred rather than automatic. `SkipCleanup` exists specifically so a gate-validation flow can keep the worktree around after the agent finishes to inspect it. On `Shutdown`, the manager force-cleans anything still outstanding.

## How the orchestrator dispatches and cancels

`Spawn` is the entry point. It validates the agent config, resolves the role's model, `Acquire`s a slot from the pool, generates an id of the form `<name>-<nanotimestamp>`, decides on a worktree, builds `SpawnOpts`, and calls `dispatchSpawn`. The returned `*Process` is tracked in an `agents` map keyed by id, and a forwarding goroutine republishes its events on a caller-facing channel. If anything fails before the process is tracked, `abandonSpawn` releases the pool slot and cleans up any worktree that was just created.

Cancellation is layered. Each `Process` carries a `cancel` func — for pi children it's the context cancel that `exec.CommandContext` turns into a process-tree kill via platform-specific process-group attrs; for ACP sessions it's `sess.Cancel()` plus the context cancel. `Orchestrator.Cancel(agentID)` marks a single agent `canceled` and calls through. `Shutdown` flips a `closed` flag (after which `Spawn` refuses with "orchestrator is shut down"), cancels every `running` agent, waits up to a timeout for graceful exit, then force-cleans all worktrees. `SpawnWithRetry` wraps `Spawn` to relaunch an agent that crashed before producing anything, up to a small retry cap.

## Guardrails: bounded concurrency and focused tasks

The pool is what keeps things from blowing up. The default is `DefaultPoolSize = 3` concurrent subagents per process — deliberately modest, because a spawned coordinator builds its own pool and the budgets multiply with nesting. The code is blunt about why: measured over six hours of runs, 39% of sessions died on the provider's per-minute token limit at a peak of eight agents in flight. You can raise it with `PI_SUBAGENT_CONCURRENCY`, clamped to a ceiling of 64, but the child budget is *not* inherited as-is. `childConcurrency` halves it with each level of nesting and floors at 1, so total concurrency converges instead of growing with depth — deeply nested work degrades gracefully to "one thing at a time," which is what you want that far from the top-level run.

The `subagent` tool caps a single call at eight tasks in parallel or chain mode, but that's a per-call name cap — the pool size is what actually gates concurrency. A batch larger than the pool queues rather than running all at once, and the call takes proportionally longer. Timeouts are two-tiered: an absolute cap and an inactivity timer that separates "slow" from "wedged," so a long-but-productive agent isn't killed on the same rule as one that has hung. And a frontmatter `timeout:` that's implausibly small (under 1000ms) is treated as a unit mistake — a bundled agent once shipped `timeout: 30` and was SIGKILLed 30ms in, every time, unable to emit a single token — so it's ignored in favor of the default rather than honored.

## The shape of a run

Put together, a fan-out looks like this: the main agent calls `subagent` in parallel mode with three tasks — two `explore` agents on different parts of the codebase and one `plan` agent. The orchestrator acquires three slots (or queues against the pool), spawns three `pi --mode json` children with the `smol` and `plan` models, streams their events back tagged with `agent_id`, and collects each result. If one of them then needs to make changes, the main agent spawns a `task` agent; it gets a worktree, runs to completion against the `default` model with a 30-minute absolute cap, and returns a handoff summary. If you want a second opinion from a different vendor, you spawn `claude` or `gemini` and the same event stream comes back over ACP.

```
# Raise the per-process subagent budget (clamped to 64)
$ PI_SUBAGENT_CONCURRENCY=6 pi

# Add a project agent that shadows a bundled one
$ cat .pi-go/agents/explore.md
---
name: explore
description: Our team's explore variant, restricted to read tools
role: smol
worktree: false
tools: read, grep, find, tree, ls
---
You are a research agent…
```
