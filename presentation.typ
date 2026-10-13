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
  That's all the maths you need.
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
  All the snippets combined into one program: 55 B in, 3.6 MB uploaded, 1.4 MB back.
  The output is a fixed mask, never a list: its length would leak.
]

== Timings

#speaker-note[Every step is 10⁹× slower; a day takes 30 s against 18 ns.]

== Where the time goes

#speaker-note[`budget_hour` and `total` are 63% of the time: sums are TFHE's weak spot.]

= FHE in the real world

== Schemes & deployments

#speaker-note[
  The scheme decides what's cheap: batching makes sums nearly free.
  Real deployments are small, targeted lookups.
]

== Weird pitfalls

#speaker-note[
  No integrity, and shared decryptions can leak the key. The fix depends on the scheme.
]

= Takeaway

== When is FHE worth it?

#speaker-note[
  FHE vs TEE vs MPC vs ZK. "In theory the Holy Grail, in practice hell." QR code to the repo.
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
