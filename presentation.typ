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

== The Holy Grail

#speaker-note[
  (1:30) Open with the quote: for 30 years FHE was "the never-to-be-found Holy Grail of cryptography" (Micciancio, CACM 2010). Gentry built the first scheme in 2009. \
  The promise: send encrypted data, the cloud computes on it without ever seeing it, you decrypt the result. Medical data, finance, AI on private data. \
  [next] Simplest operation: compare 2 bytes \
  · encrypted: ≈40 ms, ≈130 KB of ciphertext \
  · plain: 2 bytes, ≈60 million comparisons in the same time \
  [next] Thesis, slowly: in theory, the Holy Grail. In practice, a long quest. → what the quest looks like in code \
  Sources: Micciancio, CACM 53(3) 2010; Gentry, STOC 2009 (research/history-and-bottlenecks.md). Numbers: gt_u8 in bench/results.
]

#[
#set align(center)
#text(size: 1.1em)[_"the never-to-be-found Holy Grail of cryptography"_]
#v(-0.3em)
#text(size: 0.6em, fill: gray.darken(20%))[D. Micciancio, CACM 2010, on FHE before Gentry's 2009 scheme]
#v(0.5em)
#text(size: 0.75em)[
  #box(inset: 0.5em, stroke: 1pt + navy, radius: 3pt)[🔒 your data]
  #h(0.3em) → #h(0.3em)
  #box(inset: 0.5em, stroke: 1pt + navy, radius: 3pt)[the cloud computes, never decrypts]
  #h(0.3em) → #h(0.3em)
  #box(inset: 0.5em, stroke: 1pt + navy, radius: 3pt)[🔒 result, only you can read it]
]
#pause
#v(0.8em)
#let gt-fhe = median("fhe", "gt_u8")
#let gt-plain = median("plain", "gt_u8")
`a > b` on two encrypted bytes:
#text(size: 1.6em, fill: navy)[*#fmt-time(gt-fhe)*] and
#text(size: 1.6em, fill: navy)[*#str(calc.round(2 * bytes("FheUint8") / 1e3)) KB*] \
#text(size: 0.8em)[In plain: 2 bytes, and *#str(calc.round(gt-fhe / gt-plain / 1e6)) million* comparisons in those #fmt-time(gt-fhe).]
#pause
#v(0.6em)
#text(size: 1.2em)[In theory, the Holy Grail. *In practice, a long quest.*]
]

== About me

#slide(composer: (3fr, 2fr))[
  #speaker-note[
    (0:30) One sentence: SaaS developer and consultant at Codexa, MSc HES in cybersecurity. \
    Why this topic: applied research in cryptography; I wanted to see FHE from the developer's chair, not the paper's. \
    Contact on the slide; happy to talk after the talk.
  ]
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
  (0:30) Not a lattice lecture; one slide of maths, then code. \
  1. Take normal code and rewrite it for FHE, snippet by snippet: what changes and why. \
  2. Put the snippets together in one program, a smart meter, and measure time and size. \
  3. Zoom out: schemes, pitfalls, and when FHE is worth it.
]

#[
#let part(n, title, body) = box(
  width: 100%, height: 7.5em, inset: 0.8em, radius: 4pt, stroke: 1.5pt + navy,
  align(center)[
    #text(size: 1.6em, fill: c-plain)[*#n*] \
    *#title* \
    #text(size: 0.75em, body)
  ],
)
#grid(
  columns: (1fr, auto, 1fr, auto, 1fr),
  column-gutter: 0.6em,
  align: horizon,
  part[1][Rewriting code][small snippets: how the code must change],
  text(fill: navy, size: 1.5em)[→],
  part[2][The overhead][one program: what it costs in time and size],
  text(fill: navy, size: 1.5em)[→],
  part[3][The real world][schemes, pitfalls, and when it is worth it],
)
]

= FHE in one slide

== How FHE works

#speaker-note[
  (1:00) \
  Equation: compute on ciphertexts, decrypt → same result as in plain \
  · "=" is exact for TFHE, BFV/BGV (rounding removes the noise) \
  · CKKS: "≈", the noise stays in the result \
  NOISE (on screen, not written: say it) \
  · every ciphertext carries noise: that is what makes it secure \
  · every operation adds noise; × much more than + \
  · past the red line: decryption gives garbage \
  Bootstrap: resets the noise; in TFHE also applies a lookup → "two moves" \
  Server key = secret key encrypted under itself → lets the server bootstrap \
  Sources: research/operations.md, research/ciphertext-size.md
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
)
#let h = 5em
#align(center, block(width: 60%, {
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
  (bootstrapping). Everything else is built from those. \
  The server bootstraps with the *server key*: the secret key, encrypted under itself.
]
]

== Integers in TFHE

#speaker-note[
  (1:00) A ciphertext only holds a few bits: TFHE-rs splits an integer into blocks of 2 bits, each its own ciphertext. An FheUint8 is 4 blocks, an FheUint32 is 16. \
  Adding blocks is cheap, but the carries must move from block to block, and each carry is a bootstrap. A comparison is a lookup per pair of blocks, then lookups to combine. \
  Mental model for the rest of the talk: cost ≈ number of bootstraps ≈ number of blocks. More bits, more blocks, slower and bigger. \
  Our gt_u8: about 7 bootstraps, about 40 ms. \
  Size: 1 byte → 66 KB (u32: 264 KB), every bit costs space and time. If asked why: backups "66 KB", "How is one block encrypted?" \
  Sources: research/operations.md (tfhe 1.8.1 source), research/ciphertext-size.md.
]

#[
#set text(size: 0.8em)
`FheUint8` = 4 ciphertexts of *2 bits* each:
#v(0.3em)
#align(center, block(width: 80%, stack(dir: ltr, spacing: 3pt,
  ..range(4).map(i => block-box(24.5%, cyan.lighten(60%))[2 bits]))))
#v(0.8em)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 2em,
  align: top,
  [
    *$a + b$*
    - add block by block: cheap
    - move each *carry* to the next block: *a bootstrap each*
  ],
  [
    *$a > b$*
    - compare each pair of blocks: a lookup
    - combine the results: more lookups
  ],
)
#v(0.8em)
#align(center, text(size: 1.2em)[
  Cost ≈ number of bootstraps ≈ number of blocks. \
  #v(0.3em)
  Size: *1 byte → #kb("FheUint8")* \
  #text(size: 0.75em, fill: gray.darken(20%))[`u16`: 8 blocks, #kb("FheUint16") · `u32`: 16 blocks, #kb("FheUint32")]
])
]

= Rewriting code

== Init

#speaker-note[
  (1:00) Plain code: nothing to set up. FHE: the client generates two keys. \
  The client key stays at home: it decrypts. The server key goes to the server once: it lets the server compute (bootstrapping) without being able to decrypt. \
  It weighs 181 MB: 60 MB bootstrapping key, 60 MB key-switching key, and 60 MB for an encrypted-random-number key that is on by default and that we never use. \
  Then every input is encrypted on the client. \
  If asked why so big: backup slides "66 KB" and research/ciphertext-size.md.
]

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

== Branching

#speaker-note[
  (1:00) Step 1: the obvious code, an if on an encrypted comparison. Rust refuses: gt returns an FheBool, not a bool. Real rustc error. \
  That is the type system protecting you: the server cannot know the result, so it cannot pick a branch. \
  [next] Step 2: compute both sides and select. Here: always add, 1 or 0. \
  Every select costs bootstraps. Backup: "How does select work?" (research/operations.md).
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
  (1:00) \
  Plain: return at the first hour over budget → early exit \
  FHE: loop length would leak the answer (timing) → always 24 hours \
  RETHINK, not just rewrite: \
  · question changes: "when do we cross?" → "how many hours stay within?" \
  · works because `used` only grows → within-hours all come first \
  · count of within-hours = index of first hour over (never over: 24 = 24) \
  · example, budget 15: used 5, 10, 16, 23 → plain stops at 2, FHE counts 2 \
  FHE forced us to find a property of the data → no branch, no flag \
  Most expensive step: ≈13 s \
  Equality checked on every run (bench asserts plain == FHE)
]

#snippet(
  plain("budget_hour", hl: (5, 6, 7)),
  fhe("budget_hour", hl: (11, 12)),
  [No early exit: always run all 24 hours. Here, *rethink* the algorithm: count instead of stopping.],
)

== Secret index

#speaker-note[
  (1:00) TARIFFS[tier]: the memory address depends on the secret, and memory access patterns leak (think cache side channels). \
  FHE: compare tier with every index, keep the matching price, add them up. O(1) becomes O(n). \
  Fine for 4 tariffs (cheapest step, under a second). For a big table, this is why private information retrieval is a research field of its own (Apple uses it).
]

#snippet(
  plain("tariff_lookup", hl: (2,)),
  fhe("tariff_lookup", hl: (4, 5, 6, 7)),
  [The memory access would reveal the index: visit *every* slot. O(1) becomes O(n).],
)

= The overhead

== Smart meter

#speaker-note[
  (2:00) The scenario: a smart meter sends hourly readings. They reveal when you are home. We want the bill, the peaks and the budget, without the provider seeing the readings. \
  Seven steps, each one is a snippet you just saw. \
  Sizes: the 181 MB server key once; then every day 3.6 MB up instead of 55 bytes, and 1.5 MB back instead of 40. \
  The output is a fixed mask of 24 flags: a list of peak hours would leak how many there are by its length. \
  The code is on GitHub; plain and FHE outputs are checked equal on every run.
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

#speaker-note[
  (2:00) Careful, log scale: each gridline is a factor 1000. \
  Plain steps take nanoseconds, FHE steps take seconds: about 10^9 for every step. A whole day: about 30 s against about 20 ns. \
  Setup: MacBook Air M4, fanless, 4 threads, sustained load (it throttles about 20 %). \
  Client side is cheap: keygen 0.5 s, encrypt 11 ms, decrypt under 0.1 ms. The whole cost is on the server. \
  If asked about more cores: backup "Why don't more cores help?".
]

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

#speaker-note[
  (1:30) Linear scale now, FHE only. \
  The two running sums, budget_hour and total, take about 60 % of the time. \
  Surprise: the secret index, the O(n) lookup, is the cheapest; with 4 entries O(n) is nothing. \
  Sums are slow because every addition carries across 16 blocks of 2 bits, and every carry is a bootstrap. Another scheme would draw another picture: next slide.
]

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
  (2:00) There is no best scheme, only the one that hurts least for your program. \
  TFHE: any function of a small value, so comparisons and lookups are fine; sums and wide integers hurt. \
  BFV and BGV: thousands of values per ciphertext, one addition adds them all; comparisons hurt. Our 24 readings fit in one ciphertext. CKKS: same on approximate reals, the ML scheme. \
  Who uses it: Apple (BFV, encrypted lookups for Caller ID, Photos, Mail), Microsoft Edge (leaked-password match), Zama (TFHE on Ethereum, about 20 transactions/s on CPU). \
  Apple and Microsoft do not even bootstrap: one shallow computation, plus a lot of non-FHE plumbing (relays, sharding, differential privacy). \
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
  (1:00) Three things people don't expect. \
  1. No integrity: ciphertexts are malleable, that is how the server computes. It can also return garbage and you cannot tell. \
  2. Sharing a decrypted result can leak the key: CKKS in 2021 (Li & Micciancio), exact schemes including TFHE in 2024, through rare decryption failures. \
  3. The fix depends on the scheme: TFHE-rs made failures astronomically rare (2^-128 since 1.0, it was 2^-40), nearly free. CKKS must add noise, which is costly, and done wrong it is worse than nothing (Guo et al. 2024: key from one decryption). \
  Backup: Li & Micciancio. Sources: research/attacks.md.
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
  (1:30) Every option trades a trust assumption for a cost. \
  TEE: almost free, but you trust the chip vendor, and physical attacks keep breaking them (TEE.fail 2026, under 1000 dollars of hardware). MPC: you trust that the parties don't collude; the cost is network. ZK: proves a computation, but the prover holds the data. \
  FHE: trust only the math. Price: about 10^9, and no integrity. \
  So FHE is worth it when nobody can be trusted, the computation is small and fixed, and seconds are fine. Real systems mix them: Zama is FHE plus ZK plus MPC plus TEE. \
  Close with the thesis line. Point at the QR code. \
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
  In theory, the Holy Grail. In practice, a long quest, worth it for small, well-chosen problems.
])
]

#focus-slide[
  Thanks for your attention

  #text(size: 0.6em)[Any question?]
]

#show: appendix

= Backup

== Li & Micciancio

#speaker-note[
  CKKS decryption returns m + e: the error travels with the result. Each shared result gives a linear equation in the key; enough of them give the key. \
  Exact schemes are exact only if decryption never fails; the 2024 attacks provoke and observe the rare failures. \
  Sources: ePrint 2020/1533, 2024/116, 2024/127; Guo et al. USENIX Security 2024; TFHE-rs docs. research/attacks.md.
]

#[
#set text(size: 0.7em)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 2em,
  align: top,
  [
    *The attack (CKKS, EUROCRYPT 2021)*
    - CKKS decrypts to $m + e$: the noise $e$ comes out *with* the result.
    - The client shares the decrypted result (a statistic, a prediction).
    - Each shared result is a linear equation in the secret key $s$. Enough of them: $s$ by linear algebra.
    - Worked against SEAL, HElib, PALISADE, HEAAN. Not a bug: IND-CPA does not cover it, so they defined *IND-CPA#super(typographic: false)[D]*.
  ],
  [
    *Since then*
    - 2024: *exact* schemes too (BFV, BGV, TFHE), through rare *decryption failures*: key recovery in under an hour on a laptop against several libraries (CRYPTO 2024, CCS 2024).
    - Fix for TFHE: failures astronomically rare, $2^(-128)$ by default since TFHE-rs 1.0 (it was $2^(-40)$).
    - Fix for CKKS: *noise flooding* before decrypting: bigger parameters, slower.
    - Sized for the average case instead of the worst: key from *one* decryption (USENIX Security 2024).
  ],
)
]

== Scheme comparison

#speaker-note[
  Numbers from the TFHE-rs docs (192-core server, latest docs, not pinned to 1.8.1) and the SEAL manual. \
  Krüger et al. 2025 (ePrint 2025/1460): CKKS faster on most operations, TFHE faster on comparisons. \
  Sources: research/schemes.md.
]

#[
#set text(size: 0.62em)
#table(
  columns: (auto, 1fr, 1fr, 1fr),
  stroke: (x, y) => if y > 0 { (top: 0.5pt + gray.lighten(40%)) },
  inset: (x: 0.4em, y: 0.55em),
  table.header[][*Data*][*Strengths*][*Weaknesses*],
  [*TFHE* \ 2016], [one small integer per ciphertext; TFHE-rs chains 2-bit blocks], [any function through a lookup table (programmable bootstrap); unlimited depth], [one value per ciphertext; every carry and non-linear step is a bootstrap; cost explodes with bits per block (2 bits: 4.55 ms, 8 bits: 773 ms)],
  [*BFV / BGV* \ 2012], [exact integers mod $t$, thousands of slots (8192 at $N = 8192$)], [one operation acts on all slots; cheap additions], [moving values between slots costs a key switch; comparisons need deep circuits; values must not wrap mod $t$],
  [*CKKS* \ 2017], [approximate reals, $N\/2$ slots], [fast vector arithmetic on reals; encrypted ML inference], [results are approximate; comparison = polynomial approximation of the sign; expensive bootstrapping],
)
#v(0.5em)
#align(center)[
  2025 study: CKKS faster on most operations, TFHE faster on comparisons. Libraries now *switch schemes* mid-computation (OpenFHE: CKKS ↔ FHEW).
]
]

== Why not MPC or a TEE?

#speaker-note[
  TEE overhead: under 7 % for LLM inference on H100 (arXiv 2409.03992); up to 60 % for heavy network I/O on confidential VMs (SIGMETRICS 2025). \
  Intel and AMD consider physical attacks out of scope (Battering RAM). MPC: "the bottleneck is communication" (Heath & Kolesnikov, CRYPTO 2020). \
  Sources: research/alternatives.md.
]

#[
#set text(size: 0.7em)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 2em,
  align: top,
  [
    *TEE* (SGX, TDX, SEV-SNP, GPU confidential computing)
    - Data is in *plaintext inside the chip*; the hardware is the boundary.
    - Nearly free for compute (under 7 % on an H100), more for I/O.
    - You trust the vendor and its attestation keys, and nobody with physical access:
      BadRAM (2025, about \$10), Battering RAM and TEE.fail (2026, under \$1000).
    - Used by Signal (contact discovery), Signal SVR3 across three TEE vendors.
  ],
  [
    *MPC* (secure multi-party computation)
    - The data is split between several servers; no single one sees it.
    - You trust that they *don't collude*: you need two organisations.
    - The cost is network traffic and round trips, not computation.
    - Used for the Danish sugar beet auction (2008), COVID exposure statistics (Prio), Firefox telemetry.
  ],
)
#v(0.6em)
#align(center)[
  Choose FHE when there is *one* server and you trust *neither* its hardware *nor* a second party.
]
]

== Why don't more cores help?

#speaker-note[
  Thread test, 13 Oct, one run per thread count, laptop warming up (noisy). \
  The memory-bound claim comes from accelerator papers on CKKS-style bootstrapping (de Castro et al., arXiv 2112.06396), not from our CPU measurements. \
  Sources: PLAN.md (benchmark), research/history-and-bottlenecks.md.
]

#[
#set text(size: 0.72em)
#grid(
  columns: (auto, 1fr),
  column-gutter: 2.5em,
  align: horizon,
  table(
    columns: 3,
    stroke: (x, y) => if y > 0 { (top: 0.5pt + gray.lighten(40%)) },
    align: (right, right, right),
    table.header[*Threads*][*Day*][*Speed-up*],
    [1], [84 s], [1×],
    [2], [50 s], [1.7×],
    [4], [44 s], [1.9×],
    [10], [36 s], [*2.3×*],
  ),
  [
    - *Little parallel work*: an integer is a few 2-bit blocks, and carries go from one block to the next, in order. The 32-bit multiplication scales best (3.7×), an 8-bit comparison least (1.9×).
    - *Not all cores are equal*: the M4 has 4 performance and 6 efficiency cores; threads 5 to 10 are the slow ones.
    - *Memory*: each bootstrap streams tens of MB of key material; accelerator papers find bootstrapping "heavily bound by the main memory bandwidth" (for CKKS-style schemes).
  ],
)
#v(0.6em)
#align(center)[The big gains are in GPUs and dedicated chips, not in more CPU cores.]
]

== Division

#speaker-note[
  Backup (cut from the main talk, 17 Oct) \
  average = total / 24: same result, two costs \
  · public 24 ≈ 2 s \
  · encrypted 24 ≈ 15 s, ×7 \
  keep public what can be public
]

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
  ≈3 bootstraps per block with two ciphertexts; one bootstrap of c when both sides are plain
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

