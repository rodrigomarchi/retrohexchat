# Background work is Oban, and Oban is observable

Read when adding or changing an Oban worker, queue, recurrence, or its observability.

Part of the [Agent Guide](../AGENT-GUIDE.md) (§17). Section numbers there are stable — `§17` still means this file.

---

Recurring, deferred and fire-and-forget work is durable job work. `Process.send_after/3`,
`Task.start/1` and bespoke GenServer timers are **not** acceptable substrates for anything that
must survive a restart or deploy — every one of them was migrated out.

### 17.1 The code contract

- **Every enqueue goes through `RetroHexChat.Jobs`** (or a domain scheduler that uses it). No
  domain context calls `Oban.insert`, `Oban.cancel_all_jobs`, or queries `Oban.Job` directly;
  the only other Oban reader is the operational one, `RetroHexChat.Jobs.ObanHealth`.
- **Jobs are idempotent.** Running twice must not duplicate an external effect or corrupt state.
  A job acting on a persisted entity **reloads the freshest record inside `perform/1`** — never
  trusts a snapshot taken at enqueue time. Jobs mutating JSONB or durable lists take a
  transactional lock (pattern: `jobs/rss_poll_worker.ex`).
- **Separate the four moments** in any job with a visible side effect: plan → persist state →
  deliver → schedule the successor. Collapsing them is how a retry double-delivers.
- **Return type is the retry policy.** Target gone / work no longer meaningful → `{:cancel, reason}`.
  Transient failure → `{:error, reason}`. A worker that returns `:ok` on a real failure is a
  silently lost job.
- **Declare the envelope explicitly** on every worker: `queue`, `max_attempts`, `timeout/1`,
  `backoff/1`, `tags`, plus a `unique` rule whenever the work has a natural identity.
- **HTTP inside a job goes through `RetroHexChat.Net.HTTPRetry`**: retry only transient statuses
  (`408`, `425`, `429`, `5xx`) and transport failures; never retry deterministic `4xx` such as
  `404`; cap HTTP flows at `max_attempts: 3`.
- **`args` stays small, auditable and free of sensitive data.** Large or race-prone payloads use an
  outbox/pending table, with only lookup keys in the job.

### 17.2 Recurrence

- Global maintenance recurrence uses `Oban.Plugins.Cron`. **Cron schedules future ticks; it is not
  backfill.** A sweep that must catch up after a deploy/restart also enqueues one immediate,
  unique job at boot (or on the owning supervisor's first run).
- Per-entity recurrence is **self-scheduling**: the running job enqueues its successor *after*
  persisting state (the RSS pattern).
- Every recurring flow owes the admin window a **coverage contract** — "there is a next job for
  every active target".
- Disabling or removing an entity must cancel its outstanding jobs via
  `RetroHexChat.Jobs.cancel_worker_jobs/3`.

### 17.3 Queues & tables

Queues are split by operational nature, not by convenience: `rss`, `maintenance`, `bots`,
`link_preview`, `persistence`. Concurrency is explicit per queue via env var in `config/config.exs`
+ `config/runtime.exs` (the `OBAN_RSS_CONCURRENCY` style). Any new durable table backing a worker
ships with indexes and constraints matching the real access paths: read active targets, find
expired, cancel/idempotency lookup, and the flow's natural uniqueness.

### 17.4 Observability is part of "done"

A migrated flow is not done until it exposes: job counts by queue/worker/state, execution duration,
queue time, attempts, a **normalized** error, last success, last discard/cancel, its coverage
contract, and the business numbers behind it. Domain metrics go through `RetroHexChat.Observability`.

- **`set_current_span_attributes/1` is not a metric.** It updates the OpenTelemetry span; PromEx
  needs `:telemetry` events, so numeric business fields must be emitted as whitelisted events.
- **Keep PromEx cardinality low.** Never label with nick, channel, full URL, schedule id, or an
  error message — normalize the error first.
- The Oban admin window is contract-shaped, not RSS-shaped: tabs `Overview`, `Queues`, `Bots`,
  `Maintenance`, `Previews`, `Persistence`, with health summary and durable-contract cards always
  visible above them. **When a new worker lands without final UI, record the debt** in the window's
  contract table (needed `ObanHealth` snapshot, expected metrics, expected visual state). Visual
  consolidation may wait; the operational information may not be left undefined.

### 17.5 Learned the hard way

- **A durable expiry needs the DB as its source of truth.** ETS is only a derived cache, and
  expiry-on-read in the cache does not replace an auditable materialization by a worker (global
  mute). Materialized expiry must also stay auditable — never an implicit hard delete
  (trusted devices).
- **A cleanup worker does not cover a persistence outbox.** When a snapshot can be pending, the
  domain's `save/2` edge must itself reject expired entries, or the worker resurrects dead state.
- **A pending outbox snapshot is the effective read.** Domain policy that depends on
  outbox-persisted preferences must treat a pending snapshot as authoritative until the revision is
  applied; the materialized table is sufficient only when nothing is pending.
- **Uniqueness must match the human action.** Per-channel mutes are unique per channel/target while
  unrevoked — a re-mute replaces the active row *and* the future job instead of creating a second
  source of truth.
- **Stale runtime cleanup is not a UX timeout.** For long-lived sessions, the durable cutoff stays
  conservative and the update re-confirms the row is still stale in the DB.
- **Orphan cleanup for direct-to-S3 uploads keys on bucket/key/status/age**, never a local
  checksum — there isn't one.
- **In tests, never `Process.sleep/1` as a proxy for persistence** after moving `Task.start/1` to
  Oban. Assert the job was enqueued, then drain the relevant queue.
