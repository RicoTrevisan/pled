# PLAN: Structural + AST Diff Improvements

## Overview
We need to replace Pled's snapshot equality check with a deterministic plugin model, a structured diff engine, and AST-aware comparisons for every JavaScript block. The outcome should let `pled check_remote` (and push safeguards) surface precise, human-friendly differences so users can merge confidently.

## Goals
- Canonicalize both remote (Bubble) payloads and local `src/` trees into the same typed data structures, filtering volatile fields.
- Compare canonical structures to produce deterministic, path-addressable change records, not just coarse tuples.
- Parse JS code into ASTs so whitespace or formatting tweaks no longer register as conflicts, while real logic changes produce useful summaries.
- Cache remote snapshots as the canonical representation/fingerprint so repeated checks are O(1) unless drift is detected.
- Update the CLI to expose summaries, verbose diffs, and machine-readable output for automation.

## Non-Goals
- Building a generic three-way merge/resolution tool (manual merges still happen outside Pled).
- Supporting languages beyond the JS snippets that Bubble hosts today.
- Rewriting encoder/decoder; we reuse them as data sources for the canonical model.

## Work Breakdown
1. **Infrastructure & Canonical Model**
   - Add `Pled.PluginModel` structs + constructors (`from_remote/1`, `from_local/1`, `normalize/1`, `fingerprint/1`).
   - Decide field ordering, ignored keys, and hash functions (e.g., `:crypto.hash(:sha256, term |> :erlang.term_to_binary())`).
   - Store snapshots as this model + per-entity fingerprints (JSON) under `.pled/snapshots/src.json`.

2. **Diff Engine**
   - Implement `Pled.PluginDiff` that walks two canonical trees, aligns by stable keys, emits typed change events with `path`, `before`, `after`, `meta`.
   - Provide formatter helpers for summary counts, tree output, and raw JSON (for `--json`).
   - Wire it into `Pled.RemoteChecker` so `check_remote_changes/0` returns `%PluginDiff{}` results.

3. **AST Parsing & Diffing**
   - Create `Pled.JsAst` that shells out to a vendored Node script (`priv/js/parse_ast.js`) using `esprima` or `acorn`; include cache keyed by file path + mtime.
   - Wrap JS strings in `Pled.CodeBlock` structs storing raw source, AST, hash, and parse diagnostics.
   - Build `Pled.CodeDiff` that compares AST JSON, produces semantic descriptions, and falls back to text diff when parsing fails.

4. **Snapshot & CLI Integration**
   - Update snapshot save/read to use canonical representation.
   - Enhance `pled check_remote` + push guard rails to show diff summaries, list affected files, and optionally dump AST/text previews.
   - Support `--json`/`--detailed` flags for automation.

5. **Testing & Docs**
   - Add fixture plugins under `priv/fixtures/diff_cases/` covering metadata drift, element/action churn, AST-safe changes, and parser failures.
   - Unit/integration tests for `PluginModel`, `PluginDiff`, `CodeDiff`, and CLI output.
   - Document new behavior + Node dependency in README/AGENTS.

## Risks & Mitigations
- **AST parser availability:** Vendor a Node script plus lockfile so devs don't need global installs; fail gracefully to text diff.
- **Performance:** Cache canonical models, AST outputs, and hashed fingerprints; only recompute for touched files.
- **Backward compatibility:** Provide migration path for existing `.src.json` by auto-upgrading on first run.

## Open Questions / Follow-Ups
- Should we offer a `pled diff --local` command for local vs Bubble comparisons without hitting network? (Nice-to-have)
- How much detail should `check_remote` print by default vs requiring `--verbose`? (Need UX decision once diffs exist.)
