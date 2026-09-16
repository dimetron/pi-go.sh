+++
title = 'The DeepSeek and GLM-5.3 effect'
date = 2026-08-29T00:00:00+02:00
category = 'Data'
description = 'Switching pi-go default model to DeepSeek and adding GLM-5.3 tripled my agent usage. A data-driven look at the session history.'
lede = 'Switching the default model to DeepSeek and adding GLM-5.3 produced the single biggest jump in usage I have ever recorded.'
+++

*August 2026 — a data-driven look at my pi-go agent session history*

---

## TL;DR

Switching my coding agent's default model to **DeepSeek** (via local Ollama) and adding **GLM-5.3** to the rotation produced the single biggest jump in usage I've ever recorded. Monthly session volume went from a mid-year slump of **326** to an all-time high of **1,868** — a **5.7× increase** — and the new model stack now accounts for **~54% of all sessions**.

This isn't a story about "better benchmarks." It's a story about **adoption**: when the right model becomes cheap, fast, and local, you simply use the agent more.

---

## The Data

All numbers come from my pi-go session history (`~/.pi-go/sessions`), merged across two machines. Each row is one agent session.

### Monthly session volume

| Month | Sessions | Change |
|------:|---------:|-------:|
| 2026-04 | 1,072 | — |
| 2026-05 | 503 | −53% |
| 2026-06 | 326 | −35% |
| 2026-07 | 1,060 | +225% |
| **2026-08** | **1,868** | **+76%** |

### Model mix by month (latest → oldest)

| Month | DeepSeek | GLM-5.3 | GLM (other) | Stealth | GPT-5.5 | MiniMax | Other | Total |
|------:|---------:|--------:|------------:|--------:|--------:|--------:|------:|------:|
| **2026-08** | **783** | **45** | 86 | 212 | 3 | 198 | 541 | **1,868** |
| 2026-07 | 0 | 0 | 167 | 0 | 455 | 314 | 124 | 1,060 |
| 2026-06 | 0 | 0 | 62 | 0 | 193 | 60 | 11 | 326 |
| 2026-05 | 5 | 0 | 0 | 0 | 274 | 212 | 12 | 503 |
| 2026-04 | 2 | 0 | 0 | 0 | 289 | 411 | 370 | 1,072 |

### The new stack's share of monthly usage

| Month | DeepSeek + GLM-5.3 + Stealth | Share of month |
|------:|-----------------------------:|---------------:|
| 2026-04 | 2 | 0.2% |
| 2026-05 | 5 | 1.0% |
| 2026-06 | 0 | 0.0% |
| 2026-07 | 0 | 0.0% |
| **2026-08** | **1,040** | **55.7%** |

---

## What Actually Happened

### 1. The mid-year slump (May–June)
Usage collapsed from 1,072 → 326 sessions. The old stack (GPT-5.5 + MiniMax) had plateaued. I was using the agent *less*, not more.

### 2. The DeepSeek switch (August)
I moved the default to **DeepSeek-V4-Flash via local Ollama**. The effect was immediate and dramatic:

- **783 DeepSeek sessions in August** — the single most-used model ever in one month
- **Aug 13 alone: 137 sessions** — the biggest single-day spike in the dataset
- DeepSeek went from **0% → 42%** of monthly usage in one month

### 3. GLM-5.3 joins the rotation (Aug 27)
GLM-5.3-Flash appeared **Aug 27** (38 sessions) and **Aug 29** (7 more), running through **both Ollama and OpenRouter**. It's brand new — but it's already the fastest-adopted model in the dataset, appearing across pi-go, ai-eng-course, and subagent task directories on day one.

### 4. Stealth (Aug 22+)
A third new model, **Stealth/Ox-Alpha**, ramped from Aug 22 (29) to Aug 25 (79). Together, DeepSeek + GLM-5.3 + Stealth = **1,040 sessions, 55.7% of August**.

---

## Why This Matters

The pattern is clear: **usage growth tracked model quality-per-dollar, not marketing.**

- **GPT-5.5 era (Apr–Jul):** capable but expensive → I rationed usage → volume fell.
- **DeepSeek era (Aug):** near-frontier quality, **free and local** via Ollama → no cost anxiety → I used the agent for everything → volume exploded.
- **GLM-5.3:** a fresh, fast option that slots into the rotation → more experimentation, more sessions.

The lesson for anyone building on LLMs: **the friction of cost and latency is what suppresses usage.** Remove it, and people don't just do the same work cheaper — they do *more* work.

---

## Projection (honest, not exponential)

I fit an exponential curve to the new-stack share and it produced nonsense (392%/month, >100% share) — because this is a **step change**, not organic growth. The realistic read:

- **September:** new stack likely **60–75%** of sessions (DeepSeek stays dominant, GLM-5.3 and Stealth keep growing)
- **October:** **70–85%**, approaching a ceiling
- **Realistic ceiling:** ~85–90% — the remaining `other` bucket is subagent/ACP sessions (Codex, Claude, Gemini) that will always exist

The growth is real, but it's **adoption saturation**, not a hockey stick.

---

## Data Notes

- Source: `~/.pi-go/sessions/*/meta.json`, merged from local + `dr-mac-studio` via rsync (4,805 sessions total)
- "GLM-5.3" = `glm-5.3-flash:cloud` (Ollama) + `z-ai/glm-5.3-flash` (OpenRouter)
- "Other" includes subagent/ACP sessions (Codex, Claude, Gemini) that don't record a model name
- Token figures excluded here; prompt-token counts are inflated by context re-sending
