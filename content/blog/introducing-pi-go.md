+++
title = 'Introducing Pi-Go'
date = 2026-04-18T00:00:00+02:00
category = 'Announcement'
description = 'pi-go is a terminal-based AI coding agent built on Google ADK Go with multi-provider LLM support, sandboxed tools, and Memory Palace.'
lede = 'pi-go is a terminal-based AI coding agent built on Google ADK Go. It ships as a single binary, runs multiple LLM providers side by side, keeps your filesystem safe behind a sandbox, and remembers what you have worked on across sessions.'
+++

## Why another coding agent?

The browser-tab and IDE-plugin coding agents are powerful, but they pull you out of the terminal — where real work happens. pi-go is opinionated about staying there. It’s a TUI that speaks JSON-RPC to language servers, talks to whatever LLM you prefer, and executes tools inside a strict sandbox so you don’t have to trust it beyond what it needs to see.

## What’s in the box

- **Multi-provider LLMs.** Anthropic, OpenAI, Gemini, and local Ollama models. Switch providers mid-conversation with a slash command.
- **Sandboxed tools.** File read/write/edit, shell execution, grep, find, tree, and git — all confined to the project directory via `os.Root`. No accidental `rm -rf ~`.
- **Memory Palace.** A four-layer contextual memory combining SQLite, semantic embeddings, a temporal knowledge graph, and background project miners that learn your codebase while you work.
- **LSP integration.** A JSON-RPC client for Go, TypeScript, Python, and Rust with auto-format and diagnostics hooks wired into the agent loop.
- **Subagent system.** Process-based orchestration with typed roles — explore, plan, designer, reviewer, task runner — so big tasks fan out cleanly.
- **Session branching.** JSONL append-only event logs with branching, compaction, and resume. Fork a conversation, try a different approach, merge back.

## Get started in one command

```shell
# Linux and macOS
$ curl -fsSL https://raw.githubusercontent.com/dimetron/pi-go/main/scripts/install.sh | bash

# Windows PowerShell
PS> powershell -NoProfile -Command "iwr https://raw.githubusercontent.com/dimetron/pi-go/main/scripts/install.ps1 -UseBasicParsing | iex"

# Or with go install
$ go install github.com/dimetron/pi-go/cmd/pi@latest

# Run it
$ pi
```

## What’s next

This is the first post and the project is very much in motion. Upcoming: deeper dives on the Memory Palace, the sandbox threat model, and how the subagent system dispatches work. Subscribe to the [RSS feed](/feed.xml) or watch the repo on GitHub to follow along.
