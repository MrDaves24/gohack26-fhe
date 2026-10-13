#import "@preview/touying:0.8.0": *
#import themes.metropolis: *

// Codexa brand colors, sampled from the press logo (codexa.swiss/fr/press).
#let navy = rgb("#012473")
#let cyan = rgb("#51C2F8")
// Body text: the site's "coal".
#let coal = rgb("#222222")

// Progress bar along the bottom edge of the navy header, full page width. The header
// cell has a 1em inset, so the bar is pushed back out to the cell's edges.
#let header-progress(self) = place(bottom + left, dx: -1em, dy: 1em, context block(
  width: page.width,
  components.progress-bar(height: 4pt, self.colors.primary, self.colors.primary-light),
))

#show: metropolis-theme.with(
  aspect-ratio: "16-9",
  header: self => {
    utils.display-current-heading(setting: utils.fit-to-width.with(grow: false, 100%), depth: self.slide-level)
    header-progress(self)
  },
  footer: self => self.info.short-title,
  footer-progress: false,
  config-info(
    title: [Fully Homomorphic Encryption (FHE)],
    subtitle: [Usage and limitations],
    short-title: [FHE – Usage and limitations],
    author: [Pascal Perrenoud],
    date: datetime(year: 2026, month: 10, day: 30),
    institution: [GOHack26],
  ),
  config-colors(
    primary: cyan,
    primary-light: cyan.lighten(75%),
    secondary: navy,
    neutral-dark: navy,
    neutral-darkest: coal,
  ),
  // Cyan text is too pale on a white background: alerts are navy and bold.
  config-methods(alert: (self: none, it) => text(fill: navy, weight: "bold", it)),
  config-common(new-section-slide-fn: none),
)

#set text(font: "Helvetica Neue", weight: "light")
#show raw: set text(font: "Menlo")
#set strong(delta: 200)

// --- Code snippets, read from the benchmarked code -------------------------------------

// The function `name` from a Rust file, from `pub fn name(` to its closing `}`.
// `hl` lists the lines to highlight, counted from 1 at the `fn` line.
#let code(path, name, hl: ()) = {
  let lines = read(path).split("\n")
  let start = lines.position(l => l.starts-with("pub fn " + name + "("))
  let body = ()
  for l in lines.slice(start) {
    body.push(l.trim("pub ", at: std.start, repeat: false))
    if l == "}" { break }
  }
  show raw.line: it => if it.number in hl {
    box(fill: cyan.lighten(80%), outset: (y: 2pt), width: 100%, it)
  } else { it }
  raw(body.join("\n"), lang: "rust", block: true)
}
#let plain(name, hl: ()) = code("bench/src/plain.rs", name, hl: hl)
#let fhe(name, hl: ()) = code("bench/src/fhe.rs", name, hl: hl)

// Plain left, FHE right, the workaround as a caption.
#let snippet(left, right, caption) = {
  grid(
    columns: (1fr, 1fr),
    column-gutter: 1em,
    align: top,
    row-gutter: 0.6em,
    text(size: 0.7em, fill: gray.darken(20%))[Plain Rust],
    text(size: 0.7em, fill: gray.darken(20%))[FHE (TFHE-rs)],
    text(size: 0.52em, left), text(size: 0.52em, right),
  )
  v(0.8em)
  align(center, text(size: 0.9em, caption))
}

// A labelled bar segment, for size diagrams.
#let block-box(w, fill, body) = box(
  width: w, height: 1.6em, fill: fill, inset: 0.4em, align(center + horizon, body),
)

// --- Benchmark results ------------------------------------------------------------------

#let timings = csv("bench/results/timings.csv", row-type: dictionary)
#let sizes = csv("bench/results/sizes.csv", row-type: dictionary)
// Median over runs, in nanoseconds.
#let median(impl, step) = {
  let v = timings.filter(r => r.impl == impl and r.step == step).map(r => float(r.nanos)).sorted()
  v.at(calc.div-euclid(v.len(), 2))
}
#let secs(step) = str(calc.round(median("fhe", step) / 1e9, digits: 1)) + " s"
#let bytes(item) = int(sizes.find(r => r.item == item).bytes)
#let mb(item) = str(calc.round(bytes(item) / 1e6, digits: 0)) + " MB"
#let kb(item) = str(calc.round(bytes(item) / 1e3, digits: 0)) + " KB"
// --- Charts ------------------------------------------------------------------------------

// Brand-derived series colors, checked with the dataviz validator (CVD, contrast).
#let c-plain = rgb("#1E9BD7")
#let c-fhe = rgb("#2B4DA8")
#let c-rest = gray.lighten(30%)

#let fmt-time(ns) = {
  let (v, unit) = if ns < 1e3 { (ns, "ns") } else if ns < 1e6 { (ns / 1e3, "µs") } else if (
    ns < 1e9
  ) { (ns / 1e6, "ms") } else { (ns / 1e9, "s") }
  str(calc.round(v, digits: if v < 10 { 1 } else { 0 })) + " " + unit
}

// Log scale from 0.1 ns to 100 s; bars use at most `room` of the width, the rest is
// for the value label.
#let log-lo = -1
#let log-hi = 11
#let room = 82%
#let log-frac(ns) = (calc.log(ns) - log-lo) / (log-hi - log-lo)
#let log-ticks = ((0, "1 ns"), (3, "1 µs"), (6, "1 ms"), (9, "1 s"))

#let hbar(frac, fill, label) = stack(
  dir: ltr,
  spacing: 0.4em,
  box(width: frac * room, height: 0.9em, fill: fill, radius: (right: 2pt)),
  box(height: 0.9em, align(horizon, text(size: 0.8em, label))),
)
#let gridlines = for (e, _) in log-ticks {
  place(dx: log-frac(calc.pow(10.0, e)) * room, line(angle: 90deg, length: 100%, stroke: 0.5pt + gray.lighten(50%)))
}

// One step: plain and FHE bars on the shared log axis.
#let timing-row(step) = (
  align(right + horizon, raw(step)),
  block(width: 100%, height: 1.9em, {
    gridlines
    stack(
      spacing: 2pt,
      hbar(log-frac(median("plain", step)), c-plain, fmt-time(median("plain", step))),
      hbar(log-frac(median("fhe", step)), c-fhe, fmt-time(median("fhe", step))),
    )
  }),
)

#let mb1(item) = str(calc.round(bytes(item) / 1e6, digits: 1)) + " MB"

// A horizontal arrow for the pipeline diagram: what travels above, its size below.
#let arrow(label, size, sub: none, back: false) = {
  let head = if back { "◀" } else { "▶" }
  stack(
    spacing: 0.3em,
    align(center)[#label: #size],
    box(width: 100%, {
      line(length: 100%, stroke: 1.5pt + navy)
      place(if back { left + horizon } else { right + horizon }, dy: -0.05em,
        text(fill: navy, size: 1.1em, head))
    }),
    if sub != none { align(center, text(size: 0.75em, fill: gray.darken(20%), sub)) },
  )
}
#let party(title, body) = box(
  width: 100%, inset: 0.8em, radius: 4pt, stroke: 1.5pt + navy,
  align(center)[*#title* \ #text(size: 0.75em, body)],
)

#title-slide()

= Introduction

== Hook

#speaker-note[
  FHE is "the never-to-be-found Holy Grail of cryptography" (Micciancio, CACM 2010), and it now exists.
  One encrypted comparison: 41 ms. Meanwhile your CPU does about 60 million plain ones.
  "In theory, the Holy Grail. In practice, it's hell."
]

== About me

#slide(composer: (3fr, 2fr))[
  #speaker-note[Who's talking, and why I care about crypto.]
  #text(size: 1.4em, weight: "regular")[Pascal Perrenoud]

  SaaS developer & consultant

  #set text(size: 0.85em)
  - MSc HES in cybersecurity
  - Applied research in cryptography

  #v(1em)
  #set text(size: 0.8em, fill: gray.darken(30%))
  #link("https://codexa.swiss")[codexa.swiss] \
  #link("mailto:pascal@codexa.swiss")[pascal\@codexa.swiss]
][
  #image("assets/codexa-logo.png", width: 100%)
]

== Roadmap

#speaker-note[
  How we'll look at FHE:
  (1) small snippets to see how code must be rewritten,
  (2) one scenario to measure the overhead in time and size,
  (3) what that means for choosing and using FHE.
]

= FHE in one slide

== Refresher

#speaker-note[
  Compute on ciphertexts, noise grows with each operation, bootstrapping resets it.
  TFHE has two moves: cheap linear algebra, and a lookup table that also resets the noise.
  Everything else (+, >, select, ×) is built from those (research/operations.md).
  That's all the maths you need.
]

#[
#set text(size: 0.8em)
#align(center)[
  #text(size: 1.3em)[$"Dec"("Enc"(a) plus.o "Enc"(b)) = a + b$]
  #v(0.2em)
  The server computes on ciphertexts; only the key holder can read the result.
]
#v(0.8em)
// Noise level of one ciphertext through a few operations (illustrative, not measured).
#let steps = (
  ([fresh], 15%, c-plain),
  ([$plus.o$], 25%, c-plain),
  ([$plus.o$], 38%, c-plain),
  ([$times.o$], 88%, c-plain),
  ([bootstrap], 15%, c-fhe),
  ([$plus.o$], 25%, c-plain),
  ([$times.o$], 55%, c-plain),
)
#let h = 5em
#align(center, block(width: 75%, {
  place(top, dy: -0.1em, line(length: 100%, stroke: (paint: red.darken(20%), dash: "dashed", thickness: 1pt)))
  place(top + right, dy: -1.2em, text(size: 0.8em, fill: red.darken(20%))[too much noise: decryption fails])
  grid(
    columns: steps.len(),
    column-gutter: 1fr,
    row-gutter: 0.4em,
    align: center + bottom,
    ..steps.map(((_, lvl, c)) => box(width: 1.6em, height: h, align(bottom, box(width: 100%, height: lvl, fill: c, radius: (top: 2pt))))),
    ..steps.map(((l, _, _)) => text(size: 0.85em, l)),
  )
}))
#align(center, text(size: 0.75em, fill: gray.darken(20%))[noise in one ciphertext (illustration)])
#v(0.6em)
#align(center)[
  TFHE has two moves: *cheap linear algebra*, and a *lookup table that also resets the noise*
  (bootstrapping). Everything else is built from those.
]
]

= Rewriting code

== Init

#speaker-note[Plain: nothing. FHE: keys, and a 181 MB server key shipped to the server.]

#snippet(
  ```rust
  // nothing to set up

  let x: u16 = reading;
  ```,
  ```rust
  // client: generate the keys
  let (client_key, server_key) =
      generate_keys(ConfigBuilder::default());

  // server: receives the server key, once
  set_server_key(server_key);

  // client: encrypt every input
  let x = FheUint16::encrypt(reading, &client_key);
  ```,
  [Keys first: the server key weighs *#mb("server_key")*, and the server needs it to compute.],
)
#place(bottom, dy: -0.9em, text(size: 0.5em, fill: gray.darken(20%))[
  The server key is the secret key encrypted under itself: it lets the server reset the noise
  (bootstrapping) without being able to decrypt. 181 MB = bootstrapping key 60 MB
  (918 × 4 × 2048 values) + key-switching key 60 MB (2048 × 4 × 919 values) + random-number
  (OPRF) key 60 MB, on by default. All 64-bit values: the size follows the security and
  precision parameters (TFHE-rs 1.8.1 defaults).
])

== Branching

#speaker-note[
  `if` on a secret doesn't compile (`FheBool` is not `bool`): compute both sides, then select.
  First the naive version and the real rustc 1.98 error, then the fix.
]

#alternatives[
  #snippet(
    plain("peak_count", hl: (4, 5)),
    [
      ```rust
      fn peak_count(
          readings: &[FheUint16],
          limit: &FheUint16,
      ) -> FheUint8 {
          let mut count = FheUint8::encrypt_trivial(0u8);
          for h in 0..N {
              if readings[h].gt(limit) {
                  count += 1u8;
              }
          }
          count
      }
      ```
      #text(fill: red.darken(20%))[
        ```
        error[E0308]: mismatched types
          if readings[h].gt(limit) {
             ^^^^^^^^^^^^^^^^^^^^^ expected `bool`, found `FheBool`
        ```
      ]
    ],
    [The server can't branch on a value it can't read.],
  )
][
  #snippet(
    plain("peak_count", hl: (4, 5)),
    fhe("peak_count", hl: (8, 9)),
    [No branch on a secret: always compute, then *select*.],
  )
]

== Loops

#speaker-note[
  No early exit, because the number of iterations would leak:
  loop the maximum, or rethink the algorithm (`budget_hour`).
]

#snippet(
  plain("budget_hour", hl: (5, 6, 7)),
  fhe("budget_hour", hl: (11, 12)),
  [No early exit: always run all 24 hours. Here, *rethink* the algorithm: count instead of stopping.],
)

== Secret index

#speaker-note[
  `TARIFFS[tier]` would leak through memory access: visit every slot. O(1) becomes O(n).
]

#snippet(
  plain("tariff_lookup", hl: (2,)),
  fhe("tariff_lookup", hl: (4, 5, 6, 7)),
  [The memory access would reveal the index: visit *every* slot. O(1) becomes O(n).],
)

== Division

#speaker-note[Divide by a public 24: 2.1 s. By an encrypted 24: 15.7 s. Same result.]

#snippet(
  [#plain("average") #plain("average_secret_n")],
  [
    #fhe("average", hl: (3,))
    #text(size: 1.4em)[#secs("average")]
    #fhe("average_secret_n", hl: (5,))
    #text(size: 1.4em)[#secs("average_secret_n")]
  ],
  [Divide by a *public* value whenever you can.],
)

== Bit width

#speaker-note[Choose widths up front: 1 byte becomes 66 KB, and every bit costs time.]

#snippet(
  plain("total", hl: (2, 4)),
  [
    #fhe("total", hl: (3, 5))
    #set text(size: 1.3em)
    #table(
      columns: 3,
      stroke: none,
      [`u8`], [1 B], [#kb("FheUint8")],
      [`u16`], [2 B], [#kb("FheUint16")],
      [`u32`], [4 B], [#kb("FheUint32")],
    )
  ],
  [Choose widths up front: a day in `u16` would wrap, and every bit costs size and time.],
)

= The overhead

== Smart meter

#speaker-note[
  All the snippets combined into one program: 55 B in, 3.6 MB uploaded, 1.5 MB back.
  The output is a fixed mask, never a list: its length would leak.
  Plain sizes: inputs 24 × u16 + u16 + u8 + u32 = 55 B; outputs 4+4+1+24+2+4+1 = 40 B.
]

#grid(
  columns: (1fr, 1.3fr),
  column-gutter: 1.5em,
  align: horizon,
  text(size: 0.68em)[
    ```
    // client inputs, encrypted
    readings[24], limit, tier, budget

    // server, on ciphertexts
    total       = sum(readings)
    average     = total / 24
    peak_count  = count(r > limit)
    peak_mask   = [r > limit, each hour]
    rate        = TARIFFS[tier]
    bill        = total * rate / 1000
    budget_hour = first hour over budget
    ```
  ],
  {
    set text(size: 0.7em)
    grid(
      columns: (1fr, 2fr, 1fr),
      column-gutter: 0.6em,
      row-gutter: 1.2em,
      align: horizon,
      grid.cell(rowspan: 3, party[Client (meter)][keys, encrypt, decrypt]),
      arrow[server key, once][*#mb("server_key")*],
      grid.cell(rowspan: 3, party[Server][computes, can't read]),
      arrow([inputs, every day], sub: [55 B in plain])[*#mb1("upload")*],
      arrow([results, every day], sub: [40 B in plain], back: true)[*#mb1("download")*],
    )
  },
)
#v(0.6em)
#align(center, text(size: 0.85em)[
  All the snippets in one program. The output is a *fixed-size* mask, never a list:
  its length would leak.
])

== Timings

#speaker-note[Every step is 10⁹× slower; a day takes 30 s against 18 ns.]

#[
#set text(size: 0.6em)
#let steps = ("total", "average", "peak_count", "peak_mask", "tariff_lookup", "bill", "budget_hour")
#align(right)[
  #box(width: 0.8em, height: 0.8em, fill: c-plain) Plain Rust #h(1.5em)
  #box(width: 0.8em, height: 0.8em, fill: c-fhe) FHE (TFHE-rs)
]
#grid(
  columns: (auto, 1fr),
  column-gutter: 0.8em,
  row-gutter: 0.55em,
  ..steps.map(timing-row).flatten(),
  grid.hline(stroke: 0.5pt + gray),
  ..timing-row("day"),
  [],
  block(width: 100%, height: 1em, for (e, l) in log-ticks {
    place(dx: log-frac(calc.pow(10.0, e)) * room - 1em, text(fill: gray.darken(20%), l))
  }),
)
#align(center, text(size: 1.4em)[
  One day: *#fmt-time(median("fhe", "day"))* encrypted vs #fmt-time(median("plain", "day")) in plain.
])
]

== Where the time goes

#speaker-note[`budget_hour` and `total`, the two running sums, are about 60% of the time: sums are TFHE's weak spot.]

#[
#set text(size: 0.8em)
#let steps = ("total", "average", "peak_count", "peak_mask", "tariff_lookup", "bill", "budget_hour")
#let rows = steps.map(st => (st, median("fhe", st))).sorted(key: r => -r.at(1))
#let sum = rows.map(r => r.at(1)).sum()
#let top = rows.at(0).at(1)
#let top2 = (rows.at(0).at(1) + rows.at(1).at(1)) / sum
#grid(
  columns: (auto, 1fr),
  column-gutter: 0.8em,
  row-gutter: 0.6em,
  ..rows.enumerate().map(((i, (st, ns))) => (
    align(right + horizon, raw(st)),
    hbar(ns / top, if i < 2 { c-fhe } else { c-rest },
      [#fmt-time(ns) · #str(calc.round(ns / sum * 100)) %]),
  )).flatten(),
)
#v(0.8em)
#align(center, text(size: 1.3em)[
  The two running sums, `budget_hour` and `total`, take *#str(calc.round(top2 * 100)) %*
  of the time: sums are TFHE's weak spot.
])
]

= FHE in the real world

== Schemes & deployments

#speaker-note[
  The scheme decides what's cheap: batching makes sums nearly free.
  Real deployments are small, targeted lookups.
  Sources: research/schemes.md, research/deployments.md.
]

#[
#set text(size: 0.62em)
#grid(
  columns: (1.35fr, 1fr),
  column-gutter: 1.5em,
  align: top,
  [
    #text(size: 1.3em)[*No best scheme, only the one that hurts least*]
    #v(0.3em)
    #table(
      columns: (auto, 1fr, 1fr),
      stroke: (x, y) => if y > 0 { (top: 0.5pt + gray.lighten(40%)) },
      inset: (x: 0.4em, y: 0.5em),
      table.header[*Scheme*][*Cheap*][*Expensive*],
      [*TFHE* \ small integers], [any function of a small value (lookup): compare, select], [sums and wide integers: carries cost bootstraps],
      [*BFV / BGV* \ exact integers], [thousands of values per ciphertext: one addition adds them all], [comparisons, moving values between slots],
      [*CKKS* \ approximate reals], [vector arithmetic, ML inference], [comparisons (approximated), exact results],
    )
    #v(0.3em)
    Our `total`: 24 encrypted additions in TFHE, *#secs("total")*. In BFV the 24 readings fit in one ciphertext and add up in a handful of operations.
  ],
  [
    #text(size: 1.3em)[*Who uses it*]
    #v(0.3em)
    - *Apple* (BFV, iOS 18+): Live Caller ID, landmarks in Photos, Mail logos: an encrypted lookup.
    - *Microsoft Edge* (SEAL): "is this password in a leak?", an encrypted match.
    - *Zama* (TFHE, Ethereum, Dec 2025): confidential token balances, about 20 transactions/s on CPU.
    #v(0.4em)
    #align(center)[_One encrypted question, one shallow computation, plus a lot of non-FHE plumbing._]
  ],
)
]

== Weird pitfalls

#speaker-note[
  No integrity, and shared decryptions can leak the key. The fix depends on the scheme.
  Li & Micciancio, EUROCRYPT 2021 (ePrint 2020/1533). Exact schemes: CRYPTO 2024 (ePrint 2024/116),
  CCS 2024 (ePrint 2024/127). TFHE-rs: 2^-40 in 0.8, 2^-128 since 1.0. Sources: research/attacks.md.
]

#[
#set text(size: 0.72em)
#let pitfall(title, body) = block(
  width: 100%, inset: (left: 0.8em, y: 0.3em), stroke: (left: 3pt + c-fhe),
  [*#title* \ #body],
)
#pitfall[No integrity: the server can return anything][
  Ciphertexts are malleable by design: that is how the server computes on them. A dishonest
  server can return a wrong result, and you can't tell. Verifiable FHE is still research.
]
#v(0.4em)
#pitfall[Sharing a decrypted result can leak the key][
  CKKS: Li & Micciancio (2021) recover the secret key from shared decryptions.
  2024: exact schemes too (BFV, BGV, TFHE), through rare decryption failures: under an hour
  on a laptop against several libraries.
]
#v(0.4em)
#pitfall[The fix depends on the scheme][
  TFHE-rs: make failures astronomically rare ($2^(-40)$ in v0.8, $2^(-128)$ since v1.0):
  almost free. CKKS: add noise before decrypting, which means bigger parameters and slower
  code. Our benchmark already uses the $2^(-128)$ defaults.
]
]

= Takeaway

== When is FHE worth it?

#speaker-note[
  FHE vs TEE vs MPC vs ZK. "In theory the Holy Grail, in practice hell." QR code to the repo.
  Each option trades a trust assumption for a cost; FHE trusts nothing but the math, so it costs most.
  Real systems mix them: Zama = FHE + ZK (inputs) + threshold MPC (decryption) in AWS enclaves.
  Sources: research/alternatives.md.
]

#[
#set text(size: 0.62em)
#grid(
  columns: (1.6fr, 1fr),
  column-gutter: 1.5em,
  align: horizon,
  table(
    columns: (auto, 1fr, auto, auto),
    stroke: (x, y) => if y > 0 { (top: 0.5pt + gray.lighten(40%)) },
    inset: (x: 0.4em, y: 0.55em),
    fill: (x, y) => if y == 4 { cyan.lighten(85%) },
    table.header[][*You must trust*][*Main cost*][*Integrity*],
    [*TEE*], [the chip vendor, and whoever has physical access], [≈ 0–10 %], [yes],
    [*MPC*], [that the parties don't collude], [network], [depends],
    [*ZK*], [nobody, but the prover holds the data], [$10^4$–$10^6 times$], [yes],
    [*FHE*], [*only the math*], [*≈ $10^9 times$* (our meter)], [*no*],
  ),
  [
    #text(size: 1.25em)[*FHE is worth it when*]
    - you can't trust the server, its hardware, or a second party;
    - the computation is small and fixed: a lookup, a match, a few comparisons;
    - seconds and megabytes are acceptable.
    #v(0.4em)
    Real systems mix them: Zama = FHE + ZK + MPC + TEE.
  ],
)
#v(0.8em)
#align(center, text(size: 1.5em)[
  In theory, the Holy Grail. In practice, hell, unless your problem is small.
])
]

#focus-slide[
  Thanks for your attention

  #text(size: 0.6em)[Any question?]
]

#show: appendix

= Backup

== Li & Micciancio

== Scheme comparison

== Why not MPC or a TEE?

== Why don't more cores help?

== Why is an encrypted byte 66 KB?

#speaker-note[
  Default TFHE-rs 1.8.1 parameters: 2 message bits per block, so FheUint8 = 4 blocks.
  Each block is an LWE ciphertext: 2048 random mask values + 1 body, all u64 = 16 KB.
  Details and sources: research/ciphertext-size.md.
]

#[
#set text(size: 0.8em)
`FheUint8` = 4 blocks, each carrying *2 bits*:
#v(0.2em)
#stack(dir: ltr, spacing: 3pt, ..range(4).map(_ => block-box(24%, cyan.lighten(60%))[2 bits]))
#v(0.6em)
One block = one LWE ciphertext of 64-bit values:
#v(0.2em)
#stack(
  dir: ltr,
  spacing: 3pt,
  block-box(91%, gray.lighten(60%))[mask: 2048 random values],
  block-box(8%, navy, text(fill: white)[body]),
)
#align(center)[2049 × 8 B = *16 392 B* per block, to carry 2 bits]
#v(0.6em)
#grid(
  columns: (auto, 1fr),
  column-gutter: 2em,
  table(
    columns: 3,
    stroke: none,
    align: (left, right, right),
    table.header[*Type*][*Blocks*][*Size*],
    [`FheBool`], [1], [#kb("FheBool")],
    [`FheUint8`], [4], [#kb("FheUint8")],
    [`FheUint16`], [8], [#kb("FheUint16")],
    [`FheUint32`], [16], [#kb("FheUint32")],
  ),
  align(horizon)[
    Most of it is randomness: a *compressed* ciphertext sends a seed instead of the mask.
    #v(0.4em)
    #text(size: 0.75em, fill: gray.darken(20%))[
      TFHE-rs 1.8.1 default parameters (`PARAM_MESSAGE_2_CARRY_2_KS_PBS_TUNIFORM_2M128`):
      2 message bits per block, LWE dimension 2048, modulus 2⁶⁴.
    ]
  ],
)
]

== How is one block encrypted?

#speaker-note[
  LWE (Regev 2005). Mask: random, independent of the message, so it can be a seed.
  Body: message under a one-time pad ⟨a, s⟩ that needs the key.
  Without the noise, 2048 ciphertexts give the key by Gaussian elimination.
  Adding ciphertexts adds the noises: near Δ/2 decryption fails, bootstrapping resets it.
  Δ = 2^59 checked in TFHE-rs 1.8.1 (shortint/encoding.rs). Sources: research/ciphertext-size.md.
]

#[
#set text(size: 0.8em)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 2em,
  align: top,
  [
    *Encrypt* #h(0.5em) #text(fill: gray.darken(20%))[(client, secret key $s$ = 2048 bits)]
    + mask $a$: 2048 random 64-bit values
    + noise $e$: small and random
    + body: $b = ⟨a, s⟩ + Delta dot m + e quad (mod 2^64)$

    Ciphertext $= (a, b)$
  ],
  [
    *Decrypt*
    $ b - ⟨a, s⟩ = Delta dot m + e $
    Round to the nearest multiple of $Delta$: the noise goes, $m$ stays.
    Works while $|e| < Delta \/ 2$.
  ],
)
#v(0.6em)
The 64-bit word, $Delta = 2^59$:
#v(0.2em)
#stack(
  dir: ltr,
  spacing: 2pt,
  block-box(6%, gray.lighten(40%))[pad],
  block-box(10%, cyan.lighten(40%))[carry],
  block-box(10%, cyan)[*m*],
  block-box(72%, gray.lighten(70%))[room for the noise $e$ (59 bits)],
)
#v(0.6em)
#text(size: 0.9em)[
  - The mask is pure randomness, independent of $m$: it can be sent as a *seed*.
  - The body is $m$ under a one-time pad $⟨a, s⟩$ that needs the key.
  - The noise is what makes it hard: without $e$, 2048 ciphertexts give $s$ by Gaussian
    elimination. With it, this is the *LWE* problem (Regev 2005).
]
]

== How does select work?

#speaker-note[
  select(c, a, b) = c·a + (1−c)·b: both sides always computed, result is a fresh ciphertext.
  TFHE-rs packs c next to each 2-bit block (x = 2·block + c, fits in the 4-bit block thanks
  to the carry space) and bootstraps with a lookup table "block if c else 0".
  ~3 bootstraps per block with two ciphertexts; one bootstrap of c when both sides are plain
  values (our peak_count). Sources: research/operations.md (tfhe 1.8.1, radix_parallel/cmux.rs).
]

#[
#set text(size: 0.8em)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 2em,
  align: top,
  [
    *The idea*
    $ "select"(c, a, b) = c dot a + (1 - c) dot b $
    - *Both* $a$ and $b$ are always computed.
    - The result is a *fresh* ciphertext: nobody can tell which side it came from.
  ],
  [
    *In TFHE-rs*, for each 2-bit block:
    + pack: $x = 2 dot "block" + c$ #h(0.3em) (fits thanks to the carry bits)
    + bootstrap with a lookup table: \ $f(x) = $ block if $c$, else 0
    + same for $b$ with $not c$, add, clean
  ],
)
#v(0.8em)
#align(center, table(
  columns: 3,
  stroke: none,
  align: (left, left, right),
  table.header[*Call*][*Used in*][*Bootstraps*],
  [`select(c, a, b)`, two ciphertexts], [—], [≈ 3 per block],
  [`select(c, 1, 0)`, plain values], [`peak_count`, `budget_hour`, `tariff_lookup`], [1 for the result],
))
#v(0.6em)
#align(center)[
  The magic is the *programmable bootstrap*: it resets the noise *and* applies a lookup table.
]
]

