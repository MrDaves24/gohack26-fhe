# GOHack26 — FHE talk plan

## Facts

| | |
|---|---|
| Title | **Fully Homomorphic Encryption FHE – Usage and limitations** |
| Event | GOHack26 |
| Talk | **Fri 30 Oct 2026, 15:30** — 30 min slot incl. questions → **~20 min talk** |
| Slides due | **Fri 23 Oct 2026** — **no updates after that** (backup slides must be in by then) |
| Audience | Mixed: CS students, teachers, people working in cybersecurity. Assume a CS degree and a rough idea of what FHE is; don't assume lattice math. |
| Setup | Own laptop, 16:9, venue projector. Present with pdfpc. |
| Tools | Typst 0.15 + Touying 0.8.0 (Metropolis theme); Rust + `tfhe` crate **=1.8.1** (TFHE-rs) |

## Thesis

> *"In theory, FHE is the Holy Grail of cryptography and confidential computing. In practice, it's hell."*

Lands at the end of the hook, repeated on the takeaway slide. Every slide must serve it.

**Angle:** not an FHE overview (they've seen one) and not deep math (some will know it better). Show **what it is actually like to build something with FHE**: how the code has to change, and the real cost in time and size, measured on my own laptop.

## Talk structure (~20 min)

| # | Section | Time | Content |
|---|---|---|---|
| 1 | Title | — | |
| 2 | Hook | 1:30 | Global, not tied to the scenario. (a) The promise: send encrypted data, the cloud computes without the key, you decrypt the result. "The Holy Grail." (b) The cost of one op, measured on my laptop: `a > b` on two 8-bit ints, ~0.6 ns plain vs ~37 ms TFHE-rs (×10⁷-ish), shown big, framed as throughput: "one encrypted comparison: 37 ms. Meanwhile your CPU does ~60 million plain ones." (c) Thesis line: "In practice, it's hell. Let's see what it's like to build something." |
| 3 | Me | 0:30 | |
| 4 | Roadmap | 0:30 | One visual slide (not a bullet list) |
| 5 | Refresher | 1:30 | One slide: homomorphism equation, noise grows, bootstrapping resets it. No lattices. |
| 6 | Snippet: **init** | 1:00 | Normal: nothing. FHE: params, key generation, ship server key to the server. Mention key size here. |
| 7–11 | Snippets ×5 | 5:00 | One slide per catalogue item, normal ↔ FHE side by side (see catalogue). Order for building surprise; vary layout (one slide = the Rust compile error). |
| 12 | Scenario + pipeline | 2:00 | "Putting it all together": smart meter scenario in pseudo-code (named steps), pipeline diagram client ↔ server, plain FHE sizes on the arrows (server key once, daily upload, daily download), plus one line: "with TFHE-rs compression: X MB, at the cost of Y ms server time". Code is NOT shown (it's on GitHub). |
| 13–14 | Benchmark | 3:30 | Per-step timing chart: **plain vs FHE, log scale** (same step names as the pseudo-code; plain is the reference that makes the FHE numbers mean something) + stacked share ("X% of the time is `budget_hour`"; look at the final numbers). One plain comparison, as throughput for the whole `day`: "1 household-day: ~30 s encrypted. In those 30 s, plain Rust computes ~1 billion household-days." Hardware noted (4P + 6E, fanless). Pays off the hook's one-op number. |
| 15 | Schemes & deployments | 2:00 | "No best scheme, only the one that hurts least": TFHE vs BFV/BGV vs CKKS for *this* program. Real deployments = small targeted lookups. |
| 16 | Weird pitfalls | 1:00 | One slide: no integrity; revealing decryptions can leak the key (Li & Micciancio, one line). Mitigation = more noise, bigger params → **even slower and bigger**. No side channels. |
| 17 | Takeaway | 1:30 | When FHE is worth the cost vs TEE / MPC / ZK. Thesis line again. QR code → GitHub repo. |
| 18 | Thanks | — | Focus slide: "Thanks for your attention" / "Any question?" |
| — | Backup | — | After Thanks: Li & Micciancio details, scheme comparison details, (GPU / CKKS numbers if done), "why not MPC?" |

Total: 20:00. Snippets are ~1 min each; if the first run-through is long, cut a snippet first.

## Snippet catalogue

Each snippet slide: normal Rust left, TFHE-rs right, short caption naming the workaround. Snippets are taken from the real scenario code so the slides and the benchmark match.

| Snippet | Normal | Problem in FHE | Workaround |
|---|---|---|---|
| init | nothing | params, keygen, server key transfer | — (show cost and key size) |
| branch | `if x > limit { a } else { b }` | can't branch on ciphertext (Rust refuses: `FheBool` is not `bool`) | compute both, `cond.select(a, b)` / `if_then_else` |
| loop / early exit | `while` / `break` | iteration count leaks data | fixed number of iterations + masking |
| secret index | `table[idx]` | memory access pattern leaks idx | compare idx with every position, sum masked values: O(n) |
| division | `sum / count` | division by ciphertext is very expensive | divide by a *public* value when possible |
| bit width | `u32` that might overflow | wraps silently; every bit costs time | choose widths up front |
| variable output | return filtered `Vec` | output length leaks data | fixed-size output + mask, or a count |
| debugging | `println!` | intermediate values are invisible | needs the client key (server never has it) |

Keep **5–6** of the non-init items on slides (cut list: debugging, then division can merge into bit width). The rest can be a one-line mention.

## Scenario: smart meter

Privacy motivation: hourly electricity use reveals when someone is home.

**Client inputs (encrypted):**
- `readings: [u16; 24]` — hourly consumption in Wh
- `limit: u16` — contract peak limit (encrypted; optional variant with a plaintext limit to show scalar vs ciphertext cost)
- `tier: u8` — tariff tier index, 0..4 (encrypted)
- `budget: u32` — daily energy budget in Wh (encrypted)

**Public (server side, plaintext):** `TARIFFS: [u16; 4]` (price per kWh in centimes), `N = 24`.

**Steps (names are used verbatim on the pseudo-code slide, in the code, and on the chart):**

| Step | Computes | Snippets exercised |
|---|---|---|
| `total` | sum of readings (u32) | bit width |
| `average` | `total / 24` | division by public value |
| `peak_count` | number of hours with `reading > limit` | branch → select |
| `peak_mask` | `[bool; 24]`, which hours were peaks | variable output → fixed mask |
| `tariff_lookup` | `rate = TARIFFS[tier]` | secret index |
| `bill` | `total * rate` (enc × enc multiplication) | cost of mult vs add |
| `budget_hour` | first hour where cumulative use > budget (24 if never) | loop without early exit |

**Outputs (decrypted by client):** total, average, peak_count, peak_mask, rate, bill, budget_hour.

**Correctness:** plain and FHE versions must produce identical outputs on the same inputs (asserted in code). Use a fixed RNG seed for the input data.

## Benchmark methodology

- `cargo run --release`, on **my laptop**: MacBook Air M4 (`Mac16,12`), **4 performance + 6 efficiency cores**, fanless. Say "4P + 6E cores" on the slide, not "10 cores". These are the numbers that go on the slides.
- Time every FHE step with `Instant::now()`, plus `keygen`, `encrypt`, `decrypt` as separate rows, and the whole scenario as `day`. Plain: every step, plus `day` (whole scenario), each looped 10⁶× and averaged. Single plain steps are sub-nanosecond and noisy, but kept: without a reference the FHE numbers mean nothing (decided 13 Oct, after trying FHE-only).
- Hook number: one `FheUint8` `gt` vs plain `u8 >`, timed as step `gt_u8` (median over many repeats for plain, it's ~1 ns).
- Plain baseline must use `std::hint::black_box` so it isn't optimized away.
- Repeat the full run R times (e.g. 5, fewer if too slow), report the **median**. A 5-run benchmark takes ~4 min on 4 threads.
- Threads: development runs use `RAYON_NUM_THREADS=4` (keeps the laptop usable); the final run uses all 10 cores. `meta.json` records `threads`.
- **Thermal throttling (decided: keep it).** The fanless Air slows down under sustained load: run 1 is ~15–25% faster than runs 2–5 on every FHE step. We report the plain **median**, i.e. the warm, sustained-load speed — what a busy server would see. No cooldown between runs. Slide wording: "fanless MacBook Air, sustained load".
- Timing tool: in-program `Instant` per step. FHE steps take 0.5–13 s, so timer precision is irrelevant; run-to-run variance (throttling) dominates. Criterion (built for µs–ms functions, ≥10 samples per step → ~1 h) and hyperfine (whole process only, no per-step split) were rejected.
- Sizes (`safe_serialized_size`, bytes, measured once): one ciphertext per type used (`FheUint8/16/32`, `FheBool`), plaintext equivalents, client key, server key, compressed server key (done in the template). With the scenario: `upload` (all encrypted inputs) and `download` (all encrypted outputs).
- Compression variant (optional, expendable): `CompactCiphertextList` + `CompactPublicKey` for the upload, `CompressedCiphertextList` (`enable_compression`) for the download. Size rows `upload_compact`, `download_compressed`; timed FHE steps `expand` (server unpacks the upload) and `compress` (server packs the outputs). Shows the trade-off: smaller, but slower again.
- Optional: scaling with N = 24, 48, 96 for a scaling chart.
- **Why more cores help little.** Thread test (13 Oct, `--runs 1`, 1/2/4/10 threads): whole scenario 84 s → 50 → 44 → 36 s, i.e. **10 threads ≈ 2.3× one thread**. Per step (1 → 10): `bill` 3.7×, `average_secret_n` 2.7×, `total` 2.2×, `budget_hour`/`gt_u8`/`peak_count` ~1.9×. Explanations, by strength of evidence:
  1. **Little parallel work** (fits the data): small radix integers have few blocks and carries propagate sequentially; ops with more independent work (u32 multiplication) scale best.
  2. **P/E cores**: threads 5–10 land on efficiency cores (slower, ¼ of the L2), so 4 → 10 adds little.
  3. **Memory-bound** (not shown): CPU time grows much faster than speed-up, but rayon threads spin while idle, so this doesn't prove memory stalls. Would need hardware counters; not worth it.
  Single runs during warm-up, so noisy (4 threads looked slower than 2 on `total`).
  Slide/backup wording: "10 cores ≈ 2.3× one core. More hardware helps little; the gains are in GPUs and dedicated chips." Real deployments are also IO-bound (181 MB server key per client, 3.6 MB per household-day through disk and network): say it only with a source (see To verify).

**Output files** (loaded directly by Typst for the charts):
- `bench/results/timings.csv` — `impl,step,run,nanos` (`impl` ∈ `plain`,`fhe`)
- `bench/results/sizes.csv` — `item,bytes`
- `bench/results/meta.json` — machine, cores, tfhe version, date, R

Don't decide in advance which step is worst. Look at the numbers before writing slides; adjust the story if something surprises.

## Scheme choice (for slide 15)

- **TFHE** (used here): programmable bootstrapping = arbitrary function on small ints → comparisons and lookups are native; every non-trivial op costs a bootstrap. Best Rust API.
- **BFV/BGV:** exact integers, SIMD batching (thousands of slots) → `total` nearly free; comparisons expensive.
- **CKKS:** approximate reals, great for ML inference; comparison = polynomial approximation of sign → slow, imprecise.
- Message: choosing TFHE favors the comparison-heavy steps and penalizes `total`. *No best scheme, only the least painful for your program.*
- **The example to use: summing.** `total` (24 additions) is our 2nd slowest step, 6.4 s; a month of 15-min readings (~2900 values) would take ~1 h in TFHE. With BFV/CKKS batching, thousands of values sit in one ciphertext and add up in a handful of operations: the month's total becomes cheap. Same program, the scheme alone moves a step from worst to trivial.
- Optional stretch (only if ahead of schedule): benchmark just `total` with CKKS/BFV via OpenFHE Python bindings, one extra bar.

## Could do (only if ahead of schedule)

- **Naive vs optimized.** Our FHE code is deliberately naive (readable snippets). An optimized variant of the same steps: independent hours in parallel (`peak_mask`, `peak_count`), tree sum for `total`/`budget_hour`, a faster parameter set (e.g. multi-bit). Measured as extra steps, one chart: "what an expert can win back". Plain/FHE equality still asserted.

## Notes for the slides (no measurement, no numbers)

- Our numbers are a **pessimistic** FHE: TFHE, naive code, default (most conservative) parameters, fanless laptop CPU. GPUs and dedicated accelerators are much faster, but it takes heavy optimization and special hardware to get anywhere near what a consumer laptop does in plain code. Say it in one sentence, without figures.
- Scale of the gap, from our own numbers (~10⁸–10⁹ per operation): a plain computation of 1 µs ≈ 1 h of FHE; 1 ms ≈ 2 weeks. Extrapolation, label it as such.

## To verify before putting on slides

- [ ] Deployments: Apple (BFV, iOS 18 Live Caller ID Lookup / Enhanced Visual Search), Microsoft Edge Password Monitor, Zama (confidential smart contracts / fhEVM) — check current sources.
- [ ] Li & Micciancio, Eurocrypt 2021 (IND-CPA^D, key recovery on CKKS from shared decryptions) — exact citation; one line on follow-up work on exact schemes; current library mitigations (noise flooding).
- [ ] Scheme facts above.
- [ ] FHE in deployment is memory/IO-bound rather than compute-bound (source for the backup slide).
- [ ] "Holy Grail" attribution for FHE / Gentry 2009 (hook slide).
- [ ] Time of day of the 23 Oct deadline (ask organizers).

## Schedule

| Date | Task | Done |
|---|---|---|
| Tue 13 Oct | Repo setup, `tfhe =1.8.1` hello world compiling (first build is slow), first `gt_u8` timing for the hook | [x] |
| Wed 14 Oct | Plain scenario (named steps). FHE: init/encrypt/decrypt + `total`, `peak_count` | [x] |
| Thu 15 Oct | FHE: `peak_mask`, `tariff_lookup`, `bill`, `budget_hour`, `average`. Plain == FHE check | [x] |
| Fri 16 Oct | Step timings, sizes, CSV/JSON output. README, push to GitHub. Overnight benchmark | [ ] |
| Sat 17 – Sun 18 | Buffer (Phase 1 overflow) | [ ] |
| Mon 19 Oct | Analyse numbers, adjust story. Research/verify list above | [ ] |
| Tue 20 Oct | Typst skeleton (title + one-line intent per slide), read through as a story. Snippet slides | [ ] |
| Wed 21 Oct | Pipeline diagram, charts from CSV, remaining slides, speaker notes | [ ] |
| **Thu 22 Oct** | **First timed run-through**, cut slides. Backup slides. (Non-negotiable: no updates after 23rd) | [ ] |
| **Fri 23 Oct** | Polish, **submit** | [ ] |
| Sat 24 – Thu 29 | Rehearse (once with a listener, once alone). Prepare answers to likely questions | [ ] |
| **Fri 30 Oct** | Morning run-through. Arrive early, test projector. Bring PDF + `.pdfpc` on USB, adapter | [ ] |

**If behind:** cut scope, not rehearsal. Drop a snippet (`budget_hour` is the most expendable), then the compression variant, then the scaling chart, then the CKKS stretch.

## Likely questions (prepare answers / backup slides)

- Why TFHE and not CKKS/BFV?
- How does it compare on GPU / dedicated hardware? Why doesn't more cores help? (thread scaling test)
- Why not MPC or a TEE instead?
- What exactly is the Li & Micciancio attack / is TFHE affected?
- Is it production-ready for X (AI, databases)?
