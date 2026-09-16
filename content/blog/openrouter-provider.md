+++
title = 'OpenRouter arrives in Pi-Go'
date = 2026-08-24T00:00:00+02:00
category = 'Release update'
description = 'Pi-Go now supports OpenRouter as a first-class provider. Select models with the openrouter/ prefix and use tool calling, streamed responses and reasoning tokens.'
lede = 'Pi-Go now supports OpenRouter as a first-class provider.'
+++

## One provider, many model families

OpenRouter exposes models from multiple labs behind one OpenAI-compatible API. In Pi-Go, select one by adding the `openrouter/` provider prefix to its OpenRouter model ID. The prefix is detected automatically, so no separate provider flag is needed.

```bash
# Configure your OpenRouter key
$ export OPENROUTER_API_KEY="sk-or-v1-..."

# Use a specific model
$ pi --model openrouter/google/gemini-3.7-flash

# Or let OpenRouter choose
$ pi --model openrouter/auto
```

Pi-Go uses OpenRouter's standard endpoint by default. Self-hosted gateways and compatible proxies can override it with `OPENROUTER_BASE_URL`.

## Built for agent workflows

This is more than a custom base URL. The provider is wired into Pi-Go's agent loop and model selection flow:

- **Tool calling.** OpenRouter models can invoke Pi-Go's sandboxed file, shell, search, git, and other tools.
- **Streaming.** Responses arrive incrementally in the TUI instead of waiting for a complete answer.
- **Reasoning visibility.** Reasoning-capable models stream their thinking tokens into Pi-Go's existing thinking display.
- **Accurate context limits.** Pi-Go reads OpenRouter model metadata and uses the selected model's advertised context window.
- **Thinking levels.** Pi-Go maps configured thinking levels to OpenRouter's unified reasoning effort.

## Available now

Initial OpenRouter support shipped in Pi-Go `v0.0.75`, with context-window discovery and streamed reasoning added in `v0.0.76`. Install or update Pi-Go, set `OPENROUTER_API_KEY`, and use any compatible model ID with the `openrouter/` prefix.
