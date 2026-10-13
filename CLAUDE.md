# CLAUDE.md

Repo for Pascal's GOHack26 talk **"Fully Homomorphic Encryption FHE – Usage and limitations"** (Fri 30 Oct 2026, 15:30; slides due **Fri 23 Oct**, no updates after).

**Read `PLAN.md` first.** It holds every decision: thesis, slide structure and timings, snippet catalogue, the smart meter scenario spec, benchmark methodology, schedule. Don't re-litigate settled decisions; propose changes explicitly if something in the code contradicts the plan. Tick schedule checkboxes in `PLAN.md` when tasks are done.

## Layout

```
presentation.typ     # slides (Typst + Touying, Metropolis theme)
compile.sh           # builds slides + .pdfpc into build/
build/               # generated, not committed
bench/               # Rust crate: plain vs FHE smart meter + benchmark harness
  src/plain.rs       #   plain implementation, one fn per named step
  src/fhe.rs         #   TFHE-rs implementation, same step names
  src/main.rs        #   runs both, asserts equal outputs, times steps, writes results
  results/           #   timings.csv, sizes.csv, meta.json (read by presentation.typ)
```

(Create missing pieces following this layout.)

## Rust / TFHE-rs

- Pin **`tfhe = { version = "=1.8.1", ... }`**. Do not upgrade. Check the API and required feature flags against docs.rs for **1.8.1** specifically; don't rely on memory of older/newer TFHE-rs APIs.
- Prefer the high-level API (`FheUint8/16/32`, `FheBool`, `ConfigBuilder`, `generate_keys`, `set_server_key`).
- Step names are fixed and shared across code, slides and charts: `keygen`, `encrypt`, `total`, `average`, `peak_count`, `peak_mask`, `tariff_lookup`, `bill`, `budget_hour`, `decrypt`, plus `gt_u8` (single comparison, for the hook slide).
- Each FHE step should be a small, readable function: its body is what goes on the snippet slides. Favor clarity over cleverness; add a short comment naming the FHE workaround (e.g. `// no branch: compute both, select`).
- Plain baseline: wrap inputs/outputs in `std::hint::black_box`.
- Plain and FHE outputs must be asserted equal. Fixed RNG seed for inputs.
- Always benchmark with `--release`. Timing runs are slow: tell Pascal before starting long runs, and keep a quick mode (e.g. `--quick`, R=1) for development.
- **Final numbers come from Pascal's MacBook Air**, not from a cloud/CI machine. Record machine, core count, tfhe version, date and R in `results/meta.json`.
- CSV formats: `timings.csv` = `impl,step,run,nanos`; `sizes.csv` = `item,bytes`.

## Slides (Typst)

- Typst ≥ 0.15, `@preview/touying:0.8.0`, `themes.metropolis`, 16:9 only.
- Custom header with a rainbow progress bar under the gray header (`header-progress` helper, `footer-progress: false`). Keep it.
- Focus slide at the end: big "Thanks for your attention", smaller "Any question?".
- Speaker notes via `#speaker-note[...]` (exported to `.pdfpc`).
- Charts read `bench/results/*.csv` directly (`csv()` / `json()` in Typst) so re-running the benchmark updates the slides. Log scale for timings.
- Build: `./compile.sh` → `build/presentation-16-9.pdf` + `.pdfpc`. Present with `pdfpc build/presentation-16-9.pdf`.
- Compile and visually check slides after edits (render a few pages to PNG with `typst compile ... '{p}.png'` if needed).

## Working style

- Language: English for code, slides and docs (Pascal is French-speaking; conversation may switch to French).
- ~20 min talk: slides should be sparse. One idea per slide; code snippets ≤ ~12 lines per side.
- Facts about deployments, papers and scheme properties must be verified against sources before going on a slide (see "To verify" in `PLAN.md`).
- Scope cuts over schedule slips: if behind, drop a snippet rather than rehearsal time.
