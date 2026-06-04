# Loop Implementation Prompt — RetroHexChat UI Features

This is the prompt to feed an AI coding agent **in a loop** to implement the UI-feature
backlog. Each iteration picks the next unfinished feature (or sub-task), implements it to
the platform's standards, validates with `make ci`, and records progress. Copy everything
inside the fenced block below as the agent's instruction.

---

```text
ROLE
You are implementing one increment of the RetroHexChat UI-feature backlog. RetroHexChat is
an Elixir/Phoenix LiveView umbrella app (a Windows-98-style web IRC client). Work like a
careful senior engineer who follows this project's existing conventions exactly.

AUTHORITATIVE DOCUMENTATION — READ BEFORE WRITING ANY CODE
The project already documents, in detail, how increments must be built. Treat these as law:
  1. /CLAUDE.md (repo root) — the operational rulebook:
       • CI: ALWAYS validate with `make ci` (9 parallel checks). Never run checks
         individually. A task is NOT complete if any check fails. `make ci.quick` skips
         dialyzer for fast iteration; final pass must be full `make ci`.
       • CSS Architecture: NO hardcoded hex colors or CSS values in Elixir/JS — use Tailwind
         classes / CSS custom properties. `make ci` enforces `mix audit.styles --strict`
         via CSS lint (must show 0 LOW/MEDIUM/HIGH findings).
       • SVG Architecture: NEVER write inline <svg>. All icons live in `Icons.*` submodules
         (facade at components/icons.ex); diagrams in components/diagrams.ex. Pick the icon
         submodule by what the icon DEPICTS. Browse existing icons at /showcase/icons (dev).
       • Help System: every new feature MUST add/update topics in
         RetroHexChat.Chat.HelpTopics (Commands / Features / User Interface categories),
         update the Keyboard Shortcuts topic if relevant, and add "See Also" cross-refs.
       • Code style: `mix format` enforced; every public function has an @spec; LiveViews
         MUST be thin and delegate to domain contexts; each "/" command is its own Handler.
  2. /.specify/memory/constitution.md — 11 governing principles. The non-negotiables that
     bite hardest here: IV Test-First Development (write the failing test first), VII Lean
     LiveViews & Component Architecture, VIII Retro Design Fidelity, IX Hot/Cold Data
     Separation, XI User-Facing Documentation (Mandatory).
  3. /docs/svg-catalog.md — the icon inventory (reuse before adding a new icon).
  4. /docs/ui-feature-coverage.md — the full command↔UI coverage analysis and feature
     grouping that this backlog comes from. §5 explains why each feature matters.
  5. /docs/ui-features/<NN>-*.md — the per-feature SPEC you will implement. It contains the
     real command syntax (grounded in handler source), the required entry points, dialog
     layout (ASCII wireframes), control→command mappings, permissions, and help-doc needs.
  6. /docs/ui-features/PROGRESS.md — the shared progress + learnings log.

PICK THE TASK
  • Open /docs/ui-features/PROGRESS.md. Choose the highest-priority feature whose status is
    ⬜ not started (follow the "Suggested order"). If one is 🟦 in progress, continue it.
  • Mark it 🟦 in progress in the status board before you start. If the spec is large, do ONE
    coherent sub-task per iteration (e.g. "wire the menu entry", then "add the dialog tab")
    rather than the whole feature at once — keep increments reviewable.

IMPLEMENT (follow the platform's Feature Delivery Workflow)
  1. Read the feature's spec doc end to end, plus the source files it references, so your
     command facts match reality (the spec quotes handler behavior — honor it).
  2. TDD (Principle IV): write the failing test FIRST. Use the right tag (@tag :unit |
     :integration | :liveview | :liveview_feature). For UI, prefer Phoenix.LiveViewTest.
  3. Implement to the spec:
       • Keep the LiveView thin — put logic in the domain context under
         apps/retro_hex_chat/lib/retro_hex_chat/**. Web layer only wires events/render.
       • ENHANCE existing components; never create a parallel dialog/menu. Specs 02/03 are
         "add a menu entry to an existing dialog"; 09/11 extend Channel Central.
       • Reuse existing UI primitives (components/ui/**), context-menu and dialog patterns.
       • Icons: reuse from Icons.* / svg-catalog; only add a new icon via the submodule +
         facade + @spec pattern if none fits. No inline SVG. No hardcoded colors.
       • Respect permissions/visibility from the spec (op-only, admin-only, identified-only,
         never-on-self, disabled-when-disconnected).
  4. Wire the control→command mapping exactly as the spec's table specifies.
  5. Help docs (Principle XI / CLAUDE.md): add/update HelpTopics + cross-references. This is
     part of the feature, not optional.

VALIDATE (mandatory before claiming done)
  • Run `make ci`. Fix everything it reports — in THIS project, all warnings/test failures
    are your responsibility, never "pre-existing". Re-run until fully green.
  • Run `mix audit.styles` if you touched styling (expect 0 LOW/MEDIUM/HIGH);
    final `make ci` enforces the same rule in strict mode.

RECORD (always, before you stop)
  • Update /docs/ui-features/PROGRESS.md:
       - Move the feature's status (✅ done only if fully implemented + `make ci` green +
         help docs added; otherwise leave 🟦 with a note on what remains).
       - Add a Progress-log entry (Did / Tests / Help docs / Follow-ups).
       - Add any Learnings (gotchas, patterns) to the Learnings log.
  • Keep the increment self-contained and the working tree clean.

HARD RULES
  • Do NOT git commit or push unless the user explicitly asks ("fazer o commit" or similar).
  • Do NOT add Claude/Anthropic co-author trailers to any commit.
  • Do NOT skip dialyzer, E2E, JS tests, JS lint, or CSS lint — `make ci` runs them all.
  • Do NOT make infrastructure/server changes (those go through Ansible, out of scope here).
  • If the spec contradicts the code, trust the code and note the discrepancy in PROGRESS.md
    rather than inventing behavior.

STOP CONDITION
  • Finish when the chosen unit of work is implemented, `make ci` is green, help docs are
    updated, and PROGRESS.md is written. Then stop — the loop will start the next iteration.
```

---

## How to run the loop

- **Pick-next is automatic:** the prompt reads `PROGRESS.md` each iteration, so you don't
  hand-pick the feature — just re-feed this same prompt.
- **Granularity:** large specs (01, 12) should be split into sub-tasks across iterations;
  small ones (02, 03, 04) can finish in a single pass.
- **Human gate:** commits and deploys stay manual (project rule). The loop produces clean,
  CI-green working trees; you review and commit when satisfied.
- **Definition of done per feature:** spec implemented · `make ci` green · `mix audit.styles`
  clean · HelpTopics updated · PROGRESS.md reflects ✅.
