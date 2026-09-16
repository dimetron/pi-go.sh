+++
title = 'Memory Palace: four layers of context'
date = 2026-08-29T00:00:00+02:00
category = 'Deep dive'
description = 'pi-go Memory Palace combines SQLite facts, semantic embeddings, a temporal knowledge graph, and background project miners that learn while you code.'
lede = 'The Memory Palace combines SQLite facts, semantic embeddings, a temporal knowledge graph, and background project miners.'
+++

The Memory Palace is pi-go's persistent contextual memory — SQLite facts, semantic embeddings, a temporal knowledge graph, and background project miners that turn your codebase into structured recall the agent can query on demand.

## What the Memory Palace is

Most coding agents start every session with the same blank slate: whatever fits in the system prompt plus whatever they re-read from disk. pi-go keeps a second brain on disk. Every tool call the agent makes is captured, compressed, and stored; every file in your project can be mined into searchable embeddings; relationships between entities are tracked as temporal triples that can be invalidated when the world changes. The result is the *Memory Palace* — a four-layer contextual memory that lives under `internal/palace/` and `internal/memory/` and is queried through native ADK tools and the `pi memory` command.

The palace is organized as a physical metaphor: a `Palace` holds `Drawer` records grouped into `Wing`s (one per project) and `Room`s (one per source directory). Drawers can carry a `Hall` tag — `hall_decisions`, `hall_bugs`, `hall_features`, `hall_refactors`, `hall_discoveries`, `hall_changes` — mirroring the six `ObservationType` values (`decision`, `bugfix`, `feature`, `refactor`, `discovery`, `change`) the observation pipeline emits. The `Palace` struct wires all four layers together: a `PalaceStore`, an `Embedder`, a `DrawerService`, a `Graph`, a `KnowledgeGraph`, and a `MemoryStack`.

## The four layers

The `MemoryStack` in `internal/palace/layers.go` implements a four-layer memory model. Each layer is cheaper to consult than the one below it, and the agent only descends when the upper layers don't answer.

- **L0 — Identity.** A plain-text file (`PalaceConfig.IdentityFile`) loaded by `MemoryStack.loadIdentity`. Whatever you want the agent to always know about itself or the project — zero cost, always present.
- **L1 — Essential story.** `loadEssentialStory` takes the top-K drawers for the current wing (default `L1TopK = 15`, capped at `L1MaxChars = 3200`), sorted by `Importance` then recency, grouped by room. Injected into the system prompt at session start via `Palace.WakeUp`.
- **L2 — On-demand recall.** `Palace.Recall(wing, room)` returns up to `L2MaxDrawers = 10` drawers for a specific wing/room, each truncated to `L2MaxCharsPerDrawer = 300` chars. The agent pulls this only when it needs detail about a particular area.
- **L3 — Search.** Delegated to `DrawerService.Search`: semantic cosine similarity over embeddings when an embedder is loaded, falling back to FTS5 keyword ranking otherwise. The broadest, most expensive layer — used only for explicit queries.

## Layer 1: SQLite facts

The foundation is a single SQLite database opened with `OpenDB` — pure Go via `modernc.org/sqlite`, no CGO — in WAL mode with foreign keys on and a 256 MB `mmap_size`. Migrations are versioned in `internal/memory/db.go`: version 1 creates `sessions`, `observations`, and `session_summaries` with their indexes; version 2 adds `observations_fts` and `session_summaries_fts` FTS5 virtual tables plus insert/update/delete sync triggers so the full-text index stays in lockstep with the base tables.

Capture is non-blocking. `BuildAfterToolCallback` in `internal/memory/worker.go` wraps every successful tool call into a `RawObservation` and pushes it onto a buffered channel (`NewWorker`, default buffer 100). A background goroutine drains that channel: it runs `StripPrivateFromMap` to redact `<private>...</private>` spans, calls a `Compressor` to produce a structured `Observation`, and stores it. Failed compression falls back to `fallbackObservation` so nothing is lost. An `ObservationBridge` then routes the stored observation into the palace as a `DrawerInput` via the `AfterStoreHook` — deriving `Wing` from the project basename, `Room` from the first source file's directory, `Hall` from the observation type, and `Importance` from a per-type map (decisions 8, bugfixes/features 7, discoveries 6, refactors 5, changes 4).

## Layer 2: semantic embeddings

Above the facts sits a vector index. The `Embedder` interface (`Embed(texts []string) ([][]float32, error)`) has two implementations: `localEmbedder` runs `sentence-transformers/all-MiniLM-L6-v2` in-process through `hugot`, and `ollamaEmbedder` delegates to a local Ollama daemon. Ollama is tried first when `UseOllama` is on (the default) because it is faster and retrieves better; the in-process model is the no-daemon fallback. Inputs are truncated to `maxCharLength = 512` (the model's 128-token cap) to stay within GoMLX sequence buckets.

The default build is pure Go with no native libraries. Building with the `ORT` tag swaps in ONNX Runtime with CoreML on Apple silicon, where the int8 quantized model runs on the Neural Engine. `DetectPlatformOnnxFile` picks the right weights file for the compiled backend — fp32 for pure Go (int8 kernels don't exist there and run ~3x slower), int8 for ORT. Picking the wrong pair silently costs a large multiple of runtime, which is why `ModelReady` checks for the *specific* file rather than merely the directory. `CosineSimilarity` ranks candidates; `FindDuplicates` with `DeduplicationThreshold = 0.9` keeps near-identical drawers out of the index. Download the model with:

```
# Fetch all-MiniLM-L6-v2 to the default cache
$ pi memory model download

# Check which backend and weights are in place
$ pi memory model status
```

## Layer 3: temporal knowledge graph

The third layer is a temporal triple store in `internal/palace/kg.go`. `KnowledgeGraph.Add` takes a `TripleInput{Subject, Predicate, Object, ValidFrom}`, auto-creates the subject and object `Entity` rows (`INSERT OR IGNORE`), and inserts a `Triple` with a deterministic `tripleID`. Adding an identical active triple is idempotent — it returns the existing one rather than duplicating. When the world changes, `KnowledgeGraph.Invalidate` sets `valid_to = now()` on the matching active triple instead of deleting it, so history is preserved.

Queries respect time. `KnowledgeGraph.Query(entity, asOf, direction)` filters to triples valid at a given moment; `direction` can be `"subject"`, `"object"`, or both. `KnowledgeGraph.Timeline` returns every triple for an entity in chronological order. The `Graph` type in `graph.go` sits on top of the drawers themselves: `Graph.Traverse(startRoom, maxHops)` does a BFS through rooms linked by shared wings, and `Graph.FindTunnels` surfaces rooms that bridge multiple wings — the cross-project concepts that would otherwise be invisible. Inspect the graph from the CLI:

```
# Add a fact: server uses sqlite for storage
$ pi memory kg add server uses sqlite

# Query what 'sqlite' is involved in, as of a date
$ pi memory kg query sqlite

# Full chronological history for an entity
$ pi memory kg timeline server
```

## Layer 4: background project miners

The fourth layer builds the index while you do something else. `MineProject` in `internal/palace/miner_project.go` walks a directory in five phases: collect mineable files, flatten to chunks, drop unchanged chunks, embed, and persist. It respects `.gitignore` (preferring `git ls-files --others --ignored --exclude-standard` for nested patterns, `**` globs, and negation), skips `node_modules`/`vendor`/`.git`/`dist` and friends, sniffs binaries by NUL byte, and ignores files over 512 KB. Only a curated extension list is mined — `.go`, `.ts`, `.py`, `.rs`, `.md`, `.yaml`, `.proto`, and so on.

Chunks are `defaultChunkSize = 512` characters with `defaultChunkOverlap = 64` — calibrated to the embedder's 128-token cap so the tail of each chunk actually influences its vector instead of being silently dropped. `dropUnchangedChunks` compares each chunk's `ContentHash` against the stored hash before embedding, which is where ~80% of a mining run's CPU goes — so re-mining after a one-file change re-embeds only that file. Embedding fans out across `embedWorkers` (roughly `NumCPU/3`, capped), each owning its own embedder instance because `hugot` pipelines aren't safe to call concurrently; a shared embedder was what previously limited the run to ~25% CPU. Drawers are written in one transaction via `BatchInsertDrawers`, falling back to per-row inserts so one bad row can't lose the whole batch. Room detection comes from `mempalace.yaml` if present, else the first directory component.

```
# Initialize a palace database for the current project
$ pi memory init .

# Mine files into drawers (re-runs skip unchanged chunks)
$ pi memory mine .

# See drawer / wing / room / KG counts
$ pi memory status
```

## How it stays out of the way

The palace is built to never be on the critical path. Capture is a non-blocking enqueue that drops and logs rather than stalls if the channel is full. Compression runs on a background goroutine through the `memory-compressor` subagent (a small model), and the `ObservationBridge` logs and swallows its own errors so a palace failure can never block the observation pipeline. Every layer is independently optional: a palace with no embedder still serves FTS5 keyword search; a palace with no model still serves L0/L1/L2 from the database. The `ContextGenerator` in `internal/memory/context.go` builds the injected context from the last 72 hours of observations for a project, capped at a token budget (default 8000), so the system prompt never balloons. Privacy is enforced before storage with `StripPrivate` replacing `<private>...</private>` spans with `[PRIVATE]`.

## How the agent queries it

Inside a session the agent reaches the palace through two tool surfaces. From the observation store, `CoreTools()` registers `mem-search`, `mem-timeline`, and `mem-get` — a three-step workflow: `mem-search(query)` returns a compact ranked index (~50–100 tokens/result) of `SearchResultRow`s with `ReadCost` and `WorkCost` columns; `mem-timeline(anchor=ID)` returns chronological context around a hit; `mem-get(ids=[...])` pulls full `Observation` bodies for the filtered few. From the palace itself, `PalaceTools(p)` registers eleven ADK tools when a palace is loaded — `palace_status`, `palace_search`, `palace_add_drawer`, `palace_kg_add`, `palace_kg_query`, `palace_kg_invalidate`, `palace_kg_timeline`, `palace_kg_extract`, `palace_diary_write`, `palace_diary_read`, and `palace_traverse`. Returns `nil` when the palace is disabled, so the agent simply doesn't see those tools.

## What it costs

Storage is one SQLite file per palace (`PalaceConfig.DBPath`, default `palace.db`) plus the shared observation DB under `~/.pi-go/memory/`. The embedding model is `all-MiniLM-L6-v2` — ~90 MB of weights — downloaded once via `pi memory model download`. On an M2 Max mining this repo with the fp32 model, a full run of ~17,700 chunks takes about 43 minutes at 6.9 chunks/sec with batch size 8 and four workers; incremental re-runs skip unchanged chunks and finish in seconds. The Ollama backend is an order of magnitude faster. In-session cost is the L1 budget (3200 chars) plus whatever L2/L3 the agent chooses to pull — never the whole palace. Everything degrades gracefully: lose the embedder and you keep keyword search; lose the palace and you keep the observation store; lose both and pi-go is just a stateless agent that re-reads disk.
