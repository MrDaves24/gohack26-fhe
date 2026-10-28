#import "@preview/touying:0.8.0": *
#import themes.metropolis: *
#import "@preview/codetastic:0.2.2": qrcode

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

// A section title slide, in the style of Metropolis' section slides: no header, a big
// title over the progress bar, an optional subtitle.
#let section-title(title, subtitle: none, note: none) = touying-slide-wrapper(self => {
  self = utils.merge-dicts(self, config-page(fill: self.colors.neutral-lightest))
  touying-slide(self: self, {
    if note != none { speaker-note(note) }
    set align(horizon)
    show: pad.with(x: 15%)
    text(size: 1.6em, fill: self.colors.secondary, weight: "regular", title)
    v(0.2em)
    block(width: 100%, height: 3pt, components.progress-bar(
      height: 3pt, self.colors.primary, self.colors.primary-light,
    ))
    if subtitle != none {
      v(0.3em)
      text(size: 0.9em, fill: gray.darken(30%), subtitle)
    }
  })
})

// Metropolis' focus slide, without freezing the slide counter: a frozen counter gives
// it the previous slide's number, so pdfpc takes it for an overlay of that slide and
// previews it in place of the real one.
#let focus-slide(body) = touying-slide-wrapper(self => {
  self = utils.merge-dicts(self, config-page(fill: self.colors.neutral-dark, margin: 3em))
  touying-slide(
    self: self,
    setting: it => align(horizon + center, text(fill: self.colors.neutral-lightest, size: 1.5em, it)),
    body,
  )
})

// The repo: code, results and sourced research notes.
#let repo-url = "https://github.com/MrDaves24/gohack26-fhe"
#let repo-qr(width) = stack(
  spacing: 0.4em,
  // 1-module quiet zone instead of 4: the white slide around it is margin enough.
  qrcode(repo-url, width: width, quiet-zone: 1, colors: (white, navy)),
  text(size: 9pt, fill: gray.darken(30%), repo-url.trim("https://", at: start)),
)

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

// Log scale from 0.01 ns to 1000 s, over the full width: room on both sides for the labels.
#let log-lo = -2
#let log-hi = 12
#let log-frac(ns) = (calc.log(ns) - log-lo) / (log-hi - log-lo)
#let log-ticks = ((0, "1 ns"), (3, "1 µs"), (6, "1 ms"), (9, "1 s"), (11, "100 s"))

#let gridlines = for (e, _) in log-ticks {
  place(dx: log-frac(calc.pow(10.0, e)) * 100%, line(angle: 90deg, length: 100%, stroke: 0.5pt + gray.lighten(50%)))
}
#let dot(x, fill) = place(left + horizon, dx: x - 0.35em, circle(radius: 0.35em, fill: fill, stroke: 1.5pt + white))
// "×8.5·10⁹": the slowdown, i.e. the length of the connector on a log scale.
#let ratio-label(r) = {
  let e = calc.floor(calc.log(r))
  let m = calc.round(r / calc.pow(10.0, e), digits: 1)
  [×#m · $10^#e$]
}

// A horizontal bar on a linear scale (frac of 82% of the width) with its value label.
#let hbar(frac, fill, label) = stack(
  dir: ltr,
  spacing: 0.4em,
  box(width: frac * 82%, height: 0.9em, fill: fill, radius: (right: 2pt)),
  box(height: 0.9em, align(horizon, text(size: 0.8em, label))),
)

// One step: plain and FHE dots on the shared log axis, joined by the slowdown.
#let timing-row(step) = {
  let p = median("plain", step)
  let f = median("fhe", step)
  let (xp, xf) = (log-frac(p) * 100%, log-frac(f) * 100%)
  (
    align(right + horizon, raw(step)),
    block(width: 100%, height: 1.7em, {
      gridlines
      place(left + horizon, dx: xp, line(length: xf - xp, stroke: 2pt + gray.lighten(30%)))
      place(left + horizon, dx: xp + (xf - xp) / 2 - 4em, dy: -0.75em,
        box(width: 8em, align(center, text(size: 0.75em, fill: gray.darken(30%), ratio-label(f / p)))))
      dot(xp, c-plain)
      dot(xf, c-fhe)
      place(left + horizon, dx: xp - 5em, box(width: 4.4em, align(right, text(size: 0.8em, fmt-time(p)))))
      place(left + horizon, dx: xf + 0.6em, text(size: 0.8em, fmt-time(f)))
    }),
  )
}

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
  (1:30) \
  Quote: "never-to-be-found Holy Grail of cryptography" (Micciancio 2010) \
  · 30 years: nobody knew if FHE existed · Gentry 2009: first scheme \
  The promise (diagram): encrypted data → cloud computes, never decrypts → only you read the result \
  · examples: medical data, finance, AI on private data \
  [next] Simplest operation: compare 2 bytes \
  · encrypted: time + size on screen \
  · plain: 2 bytes, tens of millions of comparisons in the same time \
  [next] Thesis, slowly: Holy Grail in theory, a long quest in practice \
  → about me, then what the quest looks like in code \
  Sources: research/history-and-bottlenecks.md; numbers: bench/results
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
    (0:30) \
    SaaS developer & consultant, Codexa \
    MSc HES cybersecurity · applied research in cryptography \
    Why this talk: FHE from the developer's chair, not the paper's \
    Contact on the slide, happy to talk after \
    → roadmap
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
  (0:30) \
  Not a lattice lecture: one slide of maths, then code \
  (1) rewrite normal code for FHE, snippet by snippet \
  (2) put it together in one program, measure time and size \
  (3) real world: schemes, a real deployment, speed-ups, pitfalls, when it's worth it \
  → first, the minimum background
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

== What is FHE?

#speaker-note[
  (1:00) \
  Computing on encrypted data: the whole idea \
  Walk the diagram: client encrypts 3 and 4 → server adds the ciphertexts → client decrypts 7 \
  · server never sees 3, 4 or 7 · only the client has the secret key \
  Equation: decrypt(operation on ciphertexts) = operation on plaintexts \
  · works for + and × \
  · + and × on bits = XOR and AND → any circuit → any computation, in theory \
  → so why isn't everything encrypted? noise \
  Sources: research/history-and-bottlenecks.md
]

#[
#set text(size: 0.8em)
#align(center, text(size: 1.3em)[*Computing on encrypted data*])
#v(0.6em)
#let val(x) = box(inset: (x: 0.5em, y: 0.35em), radius: 3pt, stroke: 0.8pt + gray)[#x]
#let enc(x) = box(inset: (x: 0.5em, y: 0.35em), radius: 3pt, fill: cyan.lighten(70%))[🔒 #x]
#let step(x) = text(size: 0.8em, fill: navy)[#x →]
#align(center, text(size: 1.25em, grid(
  columns: 7,
  column-gutter: 0.7em,
  row-gutter: 0.5em,
  align: horizon + center,
  [#val[3] #val[4]], step[encrypt], [#enc[] #enc[]], step[server: $plus.o$], enc[], step[decrypt], val[7],
  text(size: 0.75em, fill: gray.darken(20%))[client], [], [], text(size: 0.75em, fill: gray.darken(20%))[never sees the values], [], [], text(size: 0.75em, fill: gray.darken(20%))[client],
)))
#v(0.8em)
#align(center)[
  #text(size: 1.2em)[$"Dec"("Enc"(a) plus.o "Enc"(b)) = a + b quad quad "Dec"("Enc"(a) times.o "Enc"(b)) = a times b$]
]
#v(0.6em)
#align(center)[
  Only the client holds the secret key. \
  \+ and × on bits are XOR and AND: with both, you can compute *anything*.
]
]

== How FHE works

#speaker-note[
  (1:30) \
  NOISE (left, say it) \
  · every ciphertext carries noise: that is what makes it secure \
  · every operation adds noise; × much more than + \
  · past the red line: decryption gives garbage \
  · bootstrapping resets the noise (expensive) \
  3 KINDS (right) \
  · partially: one operation, old (textbook RSA ×; Paillier + 1999) · padded RSA is not homomorphic \
  · somewhat: both, until the noise is too high → Apple, Edge \
  · fully: bootstrapping → unlimited (Gentry 2009) \
  TFHE: its bootstrap also applies a lookup table → "two moves": cheap linear algebra + lookup that cleans \
  · server bootstraps with the server key (secret key encrypted under itself) \
  "=" exact for TFHE, BFV/BGV; CKKS "≈" (noise stays in the result) \
  If asked how integers work: backup "Integers in TFHE" \
  → let's write code \
  Sources: research/operations.md, research/schemes.md, research/history-and-bottlenecks.md
]

#[
#set text(size: 0.72em)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 2em,
  align: top,
  {
    align(center)[*Noise*]
    v(1.4em)
    // Noise level of one ciphertext through a few operations (illustrative, not measured).
    let steps = (
      ([fresh], 15%, c-plain),
      ([$plus.o$], 25%, c-plain),
      ([$plus.o$], 38%, c-plain),
      ([$times.o$], 88%, c-plain),
      ([bootstrap], 15%, c-fhe),
    )
    block(width: 100%, {
      place(top, dy: -0.1em, line(length: 100%, stroke: (paint: red.darken(20%), dash: "dashed", thickness: 1pt)))
      place(top + right, dy: -1.3em, text(size: 0.85em, fill: red.darken(20%))[too much noise: decryption fails])
      grid(
        columns: steps.len(),
        column-gutter: 1fr,
        row-gutter: 0.4em,
        align: center + bottom,
        ..steps.map(((_, lvl, c)) => box(width: 1.5em, height: 5em, align(bottom, box(width: 100%, height: lvl, fill: c, radius: (top: 2pt))))),
        ..steps.map(((l, _, _)) => text(size: 0.85em, l)),
      )
    })
  },
  [
    #align(center)[*Three kinds*]
    #let rung(name, what, ex) = block(
      width: 100%, inset: (left: 0.7em, y: 0.3em), stroke: (left: 3pt + c-fhe),
      [*#name* · #what \ #text(size: 0.85em, fill: gray.darken(20%), ex)],
    )
    #rung[Partially][one operation only][textbook RSA (×), Paillier (+)]
    #rung[Somewhat][\+ and ×, until the noise is too high][Apple, Microsoft Edge]
    #rung[Fully][unlimited: *bootstrapping* resets the noise][Gentry 2009: the Holy Grail]
  ],
)
#v(0.8em)
#align(center)[
  Fully homomorphic families: *BGV / BFV* (exact integers) · *CKKS* (approximate reals) · *TFHE* (small integers) \
  #v(0.2em)
  This talk: *TFHE*, with Zama's *TFHE-rs*. Its bootstrap also applies a *lookup table*.
]
]

= Rewriting code

#section-title(
  [Rewriting code with FHE],
  subtitle: [Plain Rust vs TFHE-rs, snippet by snippet],
  note: [
    Same code twice: plain Rust left, FHE right \
    Each slide: a problem, then the workaround \
    → start with what plain code doesn't even need: keys
  ],
)

== Init

#speaker-note[
  (1:00) \
  Plain: nothing to set up \
  FHE: client generates 2 keys \
  · client key: stays home, decrypts \
  · server key: sent once, lets the server bootstrap without decrypting \
  · 181 MB = 60 bootstrapping + 60 key-switching + 60 random-number key (on by default, unused) \
  Then every input encrypted on the client \
  → first real problem: an if
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
  (1:00) \
  Step 1: obvious code, if on an encrypted comparison → Rust refuses \
  · gt returns FheBool, not bool (real rustc error) \
  · type system protects you: server can't know the result, can't pick a branch \
  [next] Step 2: compute both sides, select · here: always add 1 or 0 \
  Every select = bootstraps \
  If asked: backup "How does select work?" \
  → same problem with loops
]

// Only the FHE side and the caption change. Step 2 reserves step 1's (taller) space
// invisibly, so both steps have the same height and the plain side doesn't move.
#let branch-error = [
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
]
#snippet(
  plain("peak_count", hl: (4, 5)),
  alternatives(
    branch-error,
    box[#hide(branch-error)#place(top + left, fhe("peak_count", hl: (8, 9)))],
  ),
  alternatives[
    The server can't branch on a value it can't read.
  ][
    No branch on a secret: always compute, then *select*.
  ],
)

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
  Most expensive step (see the charts later) \
  Equality checked on every run (bench asserts plain == FHE) \
  → next: indexing with a secret
]

#snippet(
  plain("budget_hour", hl: (5, 6, 7)),
  fhe("budget_hour", hl: (11, 12)),
  [No early exit: always run all 24 hours. Here, *rethink* the algorithm: count instead of stopping.],
)

== Secret index

#speaker-note[
  (1:00) \
  TARIFFS[tier]: memory address depends on the secret → access pattern leaks (cache side channels) \
  FHE: compare tier with every index, keep the match, sum \
  · O(1) → O(n) \
  · 4 tariffs: cheapest step · big tables: that's PIR, a research field (→ Apple later) \
  → what do these three have in common?
]

#snippet(
  plain("tariff_lookup", hl: (2,)),
  fhe("tariff_lookup", hl: (4, 5, 6, 7)),
  [The memory access would reveal the index: visit *every* slot. O(1) becomes O(n).],
)

== It's a circuit

#speaker-note[
  (0:30) \
  Recap of the 3 snippets: one rule → nothing may depend on secret data except the values \
  · if → mux (select) · loop → fixed, unrolled · table[i] → mux over every entry \
  · fixed widths, fixed outputs (mask, not list) \
  FPGA / VHDL / Verilog people: you already know the rules \
  Difference: a gate = ns in hardware, ms in FHE (a bootstrap) \
  If asked "how do I write this?": backup "Compiling code to FHE" (Google's transpiler used a hardware synthesis tool) \
  → now let's put the snippets together and measure \
  Sources: research/operations.md
]

#[
#set text(size: 0.75em)
#table(
  columns: (1fr, 1.3fr, 1.3fr),
  stroke: (x, y) => if y > 0 { (top: 0.5pt + gray.lighten(40%)) },
  inset: (x: 0.5em, y: 0.6em),
  table.header[*Plain code*][*FHE*][*Hardware (FPGA)*],
  [`if` on a value], [compute both, `select`], [a multiplexer],
  [`while` / `break`], [fixed number of iterations], [an unrolled loop],
  [`table[i]`], [touch every slot], [a mux over all entries],
  [`u32` "just in case"], [every bit costs time and size], [every bit costs area],
  [return a list], [fixed-size output, a mask], [fixed output ports],
)
#v(0.6em)
#align(center, text(size: 1.2em)[
  If you have written VHDL or Verilog, you already know the rules. \
  #text(size: 0.8em, fill: gray.darken(20%))[Only the gates are slower: milliseconds instead of nanoseconds.]
])
]

= The overhead

#section-title(
  [Benchmarking a real example],
  subtitle: [Using the snippets we saw],
  note: [
    Snippets are nice, but what does a whole program cost? \
    One small realistic program, measured on this laptop \
    → the scenario
  ],
)

== Smart meter: the scenario

#speaker-note[
  (1:15) \
  Meter reads consumption every hour → 24 numbers a day \
  They show your life: wake up, leave, come home, holidays \
  Today: the provider sees all of it \
  With FHE: meter sends them encrypted, provider computes, only you decrypt \
  Walk the table top to bottom: question → snippet we saw \
  Names in bold = rows on the timing chart \
  → what travels between them?
]

#[
#set text(size: 0.75em)
#let lock(x) = box(inset: (x: 0.45em, y: 0.3em), radius: 3pt, fill: cyan.lighten(70%))[🔒 #x]
#align(center, text(size: 1.15em)[
  Your meter reads your consumption *every hour*: 24 readings a day \
  #text(size: 0.8em, fill: gray.darken(20%))[They show when you wake up, leave and come home. The provider must bill you without seeing them.]
])
#v(0.3em)
#align(center)[
  Encrypted by the meter: #lock[24 readings] #lock[peak limit] #lock[tariff tier] #lock[daily budget]
]
#v(0.3em)
#table(
  columns: (auto, 1fr, auto),
  stroke: (x, y) => if y > 0 { (top: 0.5pt + gray.lighten(40%)) },
  inset: (x: 0.6em, y: 0.4em),
  table.header[*Step*][*Question the provider answers*][*Snippet*],
  [*total*], [How much did you use today?], [a sum],
  [*average*], [How much per hour?], [÷ 24 (public)],
  [*peak_count*], [How many hours above your limit?], [`if` → select],
  [*peak_mask*], [Which hours?], [fixed-size output],
  [*tariff_lookup*], [What is your price per kWh?], [secret index],
  [*bill*], [What do you pay?], [encrypted × encrypted],
  [*budget_hour*], [When did you go over budget?], [loop, no early exit],
)
]

== Smart meter: on the wire

#speaker-note[
  (0:45) \
  Sizes (arrows): \
  · server key once (181 MB) \
  · every day: MBs up instead of 55 bytes, MBs back instead of 40 \
  Output = fixed mask of 24 flags: a list of peak hours would leak its length \
  Code on GitHub; plain and FHE outputs checked equal on every run \
  → how long does it take?
]

#[
#set text(size: 0.85em)
#grid(
  columns: (1fr, 2fr, 1fr),
  column-gutter: 0.8em,
  row-gutter: 1.4em,
  align: horizon,
  grid.cell(rowspan: 3, party[Client (meter)][keys, encrypt, decrypt]),
  arrow[server key, once][*#mb("server_key")*],
  grid.cell(rowspan: 3, party[Server (provider)][computes, can't read]),
  arrow([inputs, every day], sub: [55 B in plain])[*#mb1("upload")*],
  arrow([results, every day], sub: [40 B in plain], back: true)[*#mb1("download")*],
)
#v(1em)
#align(center)[
  The output is a *fixed-size* mask, never a list: its length would leak.
]
]

== Timings

#speaker-note[
  (2:00) \
  Log scale: each gridline = ×1000 \
  Dots: plain (left) vs FHE (right) · line length = slowdown, label above \
  · every step ≈ 10^9 slower \
  · whole day: seconds vs nanoseconds (bottom line) \
  Setup: MacBook Air M4, fanless, sustained load (throttles ≈20 %) \
  Client side cheap: keygen < 1 s, encrypt ms, decrypt < 0.1 ms → cost is on the server \
  If asked: backup "Why don't more cores help?" \
  → where does the time go?
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
    place(dx: log-frac(calc.pow(10.0, e)) * 100% - 1em, text(fill: gray.darken(20%), l))
  }),
)
#align(center, text(size: 1.4em)[
  One day: *#fmt-time(median("fhe", "day"))* encrypted vs #fmt-time(median("plain", "day")) in plain.
])
]

== Where the time goes

#speaker-note[
  (1:30) \
  Linear scale now, FHE only \
  Two running sums (budget_hour, total) = majority of the time (% on screen) \
  Surprise: secret index (O(n)) is the cheapest: 4 entries \
  Sums slow: every addition carries across blocks → bootstraps \
  If asked why: backup "Integers in TFHE" \
  Another scheme → another picture \
  → the scheme matters
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

== No best scheme

#speaker-note[
  (1:30) \
  The scheme decides what is cheap: pick the one that hurts least for your program \
  · TFHE: lookups, comparisons OK; sums, wide ints hurt \
  · BFV/BGV: thousands of values per ciphertext, sums ≈ free; comparisons hurt \
  · CKKS: same on approximate reals → ML \
  · our total: seconds in TFHE (on the slide); 24 readings = 1 BFV ciphertext \
  → next: Apple picked BFV for a lookup \
  Sources: research/schemes.md
]

#[
#set text(size: 0.75em)
#table(
  columns: (auto, 1fr, 1fr),
  stroke: (x, y) => if y > 0 { (top: 0.5pt + gray.lighten(40%)) },
  inset: (x: 0.5em, y: 0.6em),
  table.header[*Scheme*][*Cheap*][*Expensive*],
  [*TFHE* \ small integers], [any function of a small value (lookup): compare, select], [sums and wide integers: carries cost bootstraps],
  [*BFV / BGV* \ exact integers], [thousands of values per ciphertext: one addition adds them all], [comparisons, moving values between slots],
  [*CKKS* \ approximate reals], [vector arithmetic, ML inference], [comparisons (approximated), exact results],
)
#v(0.5em)
#align(center)[
  Our `total`: 24 encrypted additions in TFHE, *#secs("total")*. \
  In BFV the 24 readings fit in *one* ciphertext and add up in a handful of operations.
]
]

== FHE in production: Apple Live Caller ID

#speaker-note[
  (1:30) \
  iOS 18+: who is calling? → ask a caller-ID server without revealing the number \
  FLOW \
  · phone encrypts the number (BFV) \
  · Oblivious HTTP relay: server doesn't see the IP \
  · Privacy Pass token: anonymous, but rate-limited \
  · server: encrypted lookup in the whole table (PIR) → like our Secret index, O(n) \
  · WHOSE DATA: the provider's database (spam / caller ID), plaintext on its server \
  · only the QUESTION is encrypted (by the phone, its own key) → reverse of the smart meter \
  · ciphertext × plaintext: much cheaper than ciphertext × ciphertext \
  · HOW: number → hash → position i; selector 0…0 1 0…0 encrypted; Σ selector × every row → only row i survives; O(n) like Secret index (backup slide) \
  · phone decrypts: name / spam / block \
  WHY IT WORKS \
  · one tiny question, one fixed shallow computation \
  · right scheme: BFV, batched, no bootstrapping (leveled) \
  · numbers (library example, 100k entries): query 28 KB, answer 23 KB, ≈51 ms server, 681 KB key once \
  · open source: swift-homomorphic-encryption \
  FUNNY \
  · iOS waits ≈1 s; requests time out on the network, not on the FHE (developer report, not Apple) \
  Also: Mail logos, parental filter, URL filter (PIR), Photos landmarks (encrypted dot products + DP) \
  → can hardware close the gap? \
  Sources: research/deployments.md
]

#[
#set text(size: 0.7em)
#grid(
  columns: (1.15fr, 1fr),
  column-gutter: 2em,
  align: horizon,
  {
    set text(size: 0.95em)
    grid(
      columns: (1fr, 2.2fr, 1fr),
      column-gutter: 0.6em,
      row-gutter: 1.3em,
      align: horizon,
      grid.cell(rowspan: 2, party[iPhone][encrypts the number, decrypts the answer]),
      arrow([🔒 incoming number], [*28 KB*]),
      grid.cell(rowspan: 2, party[Caller-ID server][looks it up, blind]),
      arrow([🔒 name / spam], [*23 KB*], back: true),
    )
    v(0.6em)
    align(center, text(size: 0.85em, fill: gray.darken(20%))[
      through a relay (hides the IP) and with an anonymous token
    ])
  },
  [
    *Why it works*
    - *One small question*: "who is this number?"
    - *The right scheme*: BFV, many entries per ciphertext, no bootstrapping
    - *Small numbers*: ≈ 51 ms on the server for 100 000 entries
    - *Plumbing around FHE*: relay, anonymous tokens
    #v(0.3em)
    #text(size: 0.85em, fill: gray.darken(20%))[Sizes and time: Apple's open-source library, example with 100 000 entries.]
  ],
)
#v(0.8em)
#align(center, text(size: 1.15em)[
  One encrypted question, one shallow computation, plus a lot of non-FHE plumbing.
])
]

== Making FHE faster

#speaker-note[
  (1:00) \
  Our gap: ≈10^9 (9 orders of magnitude). How much can hardware win back? \
  · GPU, 8×H100 (Zama, measured): FheUint8 compare 4.85 ms vs 41 ms on my laptop ≈ 8× \
  · FPGA, Zama HPU (AMD V80, measured): ≈ 8×H100 on 64-bit ops \
  · ASIC, Intel Heracles (DARPA DPRIVE, ISSCC 2026): 1,000–5,500× vs Xeon, research chip, no product \
  · ASIC, Niobium: 1,000–5,000×, vendor claim, no date \
  · algorithms: one bootstrap 690 ms (2015) → 13 ms (2016) → < 1 ms on a GPU today \
  No FHE chip on sale yet (as far as we found). DPRIVE goal "within 10× of plaintext": no public result \
  Maturity signal: ISO/IEC 28033-2 published Jan 2026 \
  Surprise if asked: on small types Zama's 192-core CPU beats 8×H100 on throughput; GPU wins on latency \
  → and even when it's fast enough: pitfalls \
  Sources: research/acceleration.md (Zama numbers: current docs, not pinned to 1.8.1)
]

#[
#set text(size: 0.7em)
#table(
  columns: (auto, 1.4fr, auto, 1fr),
  stroke: (x, y) => if y > 0 { (top: 0.5pt + gray.lighten(40%)) },
  inset: (x: 0.5em, y: 0.55em),
  align: (left, left, right, left),
  table.header[*Approach*][*Example*][*Speed-up*][*Status*],
  [*GPU*], [8× Nvidia H100 (Zama): `a > b` on bytes in 4.85 ms, vs 41 ms on my laptop], [≈ 8×], [measured],
  [*FPGA*], [Zama HPU on one AMD board: about as fast as 8× H100], [≈ 8×], [measured],
  [*ASIC*], [Intel Heracles (DARPA DPRIVE), vs a Xeon, on FHE primitives], [1 000–5 500×], [research chip, no product],
  [*ASIC*], [Niobium], [1 000–5 000×], [vendor claim, no date],
  [*Algorithms*], [one bootstrap: 690 ms (2015) → 13 ms (2016) → under 1 ms on a GPU today], [], [measured],
)
#v(0.6em)
#align(center, text(size: 1.3em)[
  Hardware closes about *3* of our *9* orders of magnitude, on paper. \
  #text(size: 0.75em, fill: gray.darken(20%))[No dedicated FHE chip on sale yet, as far as we found.]
])
]

== Weird pitfalls

#speaker-note[
  (1:00) \
  Three surprises: \
  (1) No integrity: ciphertexts malleable (that's how the server computes) → can return garbage, you can't tell \
  (2) Sharing decrypted results can leak the key \
  · CKKS: Li & Micciancio 2021 · exact schemes incl. TFHE: 2024, via rare decryption failures \
  (3) Fix depends on the scheme \
  · TFHE-rs: failures 2^-128 since v1.0 (was 2^-40) → nearly free \
  · CKKS: noise flooding → costly; done wrong worse than nothing (key from 1 decryption, 2024) \
  If asked: backup "Li & Micciancio" \
  → so when is FHE worth it? \
  Sources: research/attacks.md
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
  (1:30) \
  Every option trades a trust assumption for a cost \
  · TEE: ≈ free, trust the chip vendor; physical attacks keep breaking them (TEE.fail 2026, under 1000 dollars) \
  · MPC: trust non-collusion; network; heavy setup against cheaters \
  · ZKP: proves a computation, prover holds the data \
  · FHE: secrecy rests only on the math · but correct results = trust the server (and its hardware) to run the right circuit \
  · protects against a passive, honest-but-curious server, not an active one; no integrity \
  Worth it when: server may compute but must not see + small fixed computation + seconds OK \
  Real systems mix: Zama = FHE + ZKP + MPC + TEE \
  Thesis line, slowly · point at the QR code \
  If asked: backup "Why not MPC or a TEE?" \
  Sources: research/alternatives.md
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
    [*MPC*], [that the parties don't collude], [network; heavy setup against cheaters], [depends],
    [*ZKP*], [nobody, but the prover holds the data], [$10^4$–$10^6 times$], [yes],
    [*FHE*], [secrecy: *only the math* \ results: *the server* (it could run another circuit)], [*≈ $10^9 times$* (our meter)], [*no*],
  ),
  [
    #text(size: 1.25em)[*FHE is worth it when*]
    - the server may compute, but must never see the data (an honest-but-curious server);
    - the computation is small and fixed: a lookup, a match, a few comparisons;
    - seconds and megabytes are acceptable.
    #v(0.4em)
    Real systems mix them: Zama = FHE + ZKP + MPC + TEE.
    #v(0.6em)
    #align(center, repo-qr(115pt))
  ],
)
#v(0.8em)
#align(center, text(size: 1.5em)[
  In theory, the Holy Grail. In practice, a long quest, worth it for small, well-chosen problems.
])
]

#focus-slide[
  #speaker-note[
    Questions · backups ready: \
    Li & Micciancio · scheme comparison · MPC / TEE · deployments in detail · Apple's PIR lookup \
    compiling code to FHE · more cores · division · 66 KB · one block (LWE) · select
  ]
  Thanks for your attention

  #text(size: 0.6em)[Any question?]

  #v(0.5em)
  #qrcode(repo-url, width: 5em, quiet-zone: 1, colors: (white, navy))
  #v(-0.4em)
  #text(size: 0.4em)[#repo-url.trim("https://", at: start)]
]

#show: appendix

= Backup

== Li & Micciancio

#speaker-note[
  CKKS decrypts to m + e → the noise comes out with the result \
  · each shared result = one linear equation in the key · enough → key \
  · not a bug: IND-CPA doesn't cover it → IND-CPA^D \
  Exact schemes: exact only if decryption never fails · 2024 attacks provoke and observe rare failures \
  Sources: ePrint 2020/1533, 2024/116, 2024/127; Guo et al. USENIX Sec 2024; research/attacks.md
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
    - Worked against SEAL, HElib, PALISADE, HEAAN. Not a bug: IND-CPA does not cover it, so they defined #box[*IND-CPA*#text(size: 0.65em, baseline: -0.55em)[*D*]].
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
  TFHE: one small value per ciphertext, any function by lookup, every carry = bootstrap \
  BFV/BGV: thousands of exact values per ciphertext; comparisons hard \
  CKKS: approximate reals, ML; comparison = polynomial approx of sign \
  PBS cost: 2 bits 4.55 ms vs 8 bits 773 ms (192-core server, latest docs) \
  2025 study: CKKS faster on most ops, TFHE on comparisons · schemes can be switched mid-computation \
  Sources: research/schemes.md (ePrint 2025/1460)
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
  Intel and AMD consider physical attacks out of scope (Battering RAM). \
  MPC is not "FHE + network": \
  · honest parties (semi-honest): almost no crypto online, cost = bytes and round trips per multiplication/comparison \
  · cheating parties (malicious, SPDZ): preprocessing uses somewhat-HE → FHE-like CPU cost (13 ms vs 0.05 ms per mult, SPDZ CRYPTO 2012) \
  · logistic regression: 0.62 s / 62 MB (semi-honest 3PC) vs 2337 s / 226 GB (malicious MASCOT), MP-SPDZ CCS 2020 \
  Sources: research/alternatives.md.
]

#[
#set text(size: 0.63em)
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
    - Honest parties: cheap on CPU, shares as small as the data; every multiplication or comparison costs messages and round trips.
    - Against cheating parties: a heavy *setup* phase, built with homomorphic encryption: 13 ms vs 0.05 ms per multiplication (SPDZ).
    - Same task, two protocols: 0.6 s / 62 MB vs 39 min / 226 GB.
    - Used for the Danish sugar beet auction (2008), COVID exposure statistics (Prio), Firefox telemetry.
  ],
)
#v(0.6em)
#align(center)[
  Choose FHE when *one* server must compute on your data *without seeing it*, \ and neither a trusted chip nor a second party is an option.
]
]

== Deployments in detail

#speaker-note[
  Apple and Microsoft: leveled BFV, no bootstrapping → strictly "somewhat" HE (Jeremy Kun's survey calls them SHE) \
  Zama: TFHE with bootstrapping → really FHE, but ≈20 tx/s on CPU; GPU/ASIC throughput = targets \
  Edge still using HE today: UNVERIFIED (only 2021 source) \
  Sources: research/deployments.md
]

#[
#set text(size: 0.6em)
#table(
  columns: (auto, 0.9fr, 1.3fr, 1.3fr, 1fr),
  stroke: (x, y) => if y > 0 { (top: 0.5pt + gray.lighten(40%)) },
  inset: (x: 0.45em, y: 0.6em),
  table.header[][*Scheme*][*Computes*][*Around the FHE*][*Numbers*],
  [*Apple* \ iOS 18+], [BFV, no bootstrapping \ (somewhat HE)],
    [encrypted lookups (PIR): Caller ID, Mail logos, parental and URL filters; encrypted dot products for Photos landmarks],
    [Oblivious HTTP relay, Privacy Pass tokens, differential privacy (Photos)],
    [28 KB query, 23 KB answer, ≈ 51 ms server (100k entries, library example)],
  [*Microsoft Edge* \ Password Monitor, 2021], [BFV via SEAL, no bootstrapping \ (somewhat HE)],
    [encrypted "is this credential in a leak?" → encrypted true / false],
    [server-side keyed hash (OPRF); 4 billion credentials split by username hash],
    [≈ 60 000 entries per query],
  [*Zama Protocol* \ Ethereum, Dec 2025], [TFHE (TFHE-rs), bootstrapping \ (fully HE)],
    [confidential token balances and transfers],
    [ZKP on inputs, threshold MPC (13 nodes) for decryption, inside AWS enclaves],
    [≈ 20 transactions/s on CPU],
)
]

== How does Apple's lookup work?

#speaker-note[
  PIR (private information retrieval), Apple's library: MulPIR + cuckoo hash table for keywords \
  · selector × every row: ciphertext × plaintext, then sums → no bootstrapping needed \
  · query compressed; server expands it with rotations → needs the phone's evaluation key (≈681 KB, once) \
  · 2-D grid: query ≈ √n instead of n, one ciphertext × ciphertext multiplication \
  · always O(n): skipping rows would reveal the index (= Secret index slide) \
  Sources: research/deployments.md (MulPIR ePrint 2019/1483, SealPIR ePrint 2017/1142)
]

#[
#set text(size: 0.7em)
#let lock(x) = box(inset: (x: 0.35em, y: 0.25em), radius: 2pt, fill: cyan.lighten(70%))[🔒 #x]
#let row(x) = box(inset: (x: 0.35em, y: 0.25em), radius: 2pt, stroke: 0.5pt + gray)[#x]
+ *Phone*: hash the incoming number → its position $i$ in the server's table (here 3)
+ *Phone*: encrypt a *selector*, 1 at position $i$, 0 elsewhere. Encrypted, all entries look the same.
+ *Server*: multiply every row by its selector entry and add everything up: only row $i$ survives.
+ *Phone*: decrypt → the caller's name or spam label.
#v(0.5em)
#align(center, grid(
  columns: 7,
  column-gutter: 0.6em,
  row-gutter: 0.4em,
  align: horizon + center,
  [*selector*], [], [*server's table*], [], [], [], [],
  lock[0], [×], row[+41 21 … : Bakery], [], grid.cell(rowspan: 4)[$sum$ →], grid.cell(rowspan: 4, lock[Spam, block]), grid.cell(rowspan: 4)[→ phone decrypts],
  lock[0], [×], row[+41 22 … : Dr. Muller], [], 
  lock[1], [×], row[+41 79 … : Spam, block], [],
  lock[0], [×], row[+41 31 … : Pharmacy], [],
))
#v(0.6em)
#align(center)[
  The server touches *every* row (skipping one would reveal $i$): O(n), like our *Secret index*. \
  #text(size: 0.85em, fill: gray.darken(20%))[Only ciphertext × plaintext and additions: no bootstrapping needed.]
]
]

== Compiling code to FHE

#speaker-note[
  Google's FHE transpiler (2021): C++ → XLS (Google's hardware synthesis tool) → gates → TFHE \
  → literally "compile your program to a circuit" \
  Successor: HEIR (MLIR compiler, several schemes and backends). Zama: Concrete compiler (Python) \
  Sources: research/operations.md (arXiv 2106.07893)
]

#[
#set text(size: 0.75em)
#align(center, grid(
  columns: 7,
  column-gutter: 0.6em,
  align: horizon,
  party[C++][plain code],
  text(fill: navy, size: 1.4em)[→],
  party[XLS][hardware synthesis (HLS)],
  text(fill: navy, size: 1.4em)[→],
  party[Circuit][logic gates],
  text(fill: navy, size: 1.4em)[→],
  party[TFHE][each gate = a bootstrap],
))
#v(1em)
- Google's FHE transpiler (2021) compiled ordinary C++ into FHE code by going through *a hardware synthesis tool*, then running every gate with TFHE.
- "Write normal code, get a circuit" is how FHE compilers work: Google's successor *HEIR* (several schemes), Zama's *Concrete*.
- The snippets we wrote by hand are the kind of rewrite such a compiler does for you.
#v(0.3em)
#text(size: 0.8em, fill: gray.darken(20%))[Gorantala et al., "A General Purpose Transpiler for Fully Homomorphic Encryption", arXiv 2106.07893.]
]

== Why don't more cores help?

#speaker-note[
  1 → 10 threads: only 2.3× (one run each, laptop warming up, noisy) \
  · little parallel work: few blocks, carries in order · mul scales best (3.7×), compare least (1.9×) \
  · M4 = 4 performance + 6 efficiency cores \
  · memory-bound: from accelerator papers on CKKS-style bootstrapping, not our measurement \
  Sources: PLAN.md (benchmark), research/history-and-bottlenecks.md
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

== Integers in TFHE

#speaker-note[
  Backup (moved from the main talk on 28 Oct) \
  One ciphertext holds only a few bits → integer = row of 2-bit blocks (base-4 digits) \
  · FheUint8 = 4 blocks · FheUint32 = 16 \
  · why: a bootstrap = lookup table, cost explodes with bits per block \
  a + b: add blocks (cheap), then each carry → next block = a bootstrap \
  a > b: compare each pair (lookup), combine as a tree (more lookups) \
  Cost ≈ bootstraps ≈ blocks · size: 1 byte → 66 KB \
  If asked: backups "66 KB", "How is one block encrypted?", "How does select work?" \
  Sources: research/operations.md, research/ciphertext-size.md
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

== Why is an encrypted byte 66 KB?

#speaker-note[
  TFHE-rs 1.8.1 defaults: 2 message bits per block → FheUint8 = 4 blocks \
  1 block = LWE ciphertext: 2048 random mask values + 1 body, 64 bits each = 16 KB \
  mask = pure randomness → compressed ciphertexts send a seed instead \
  Sources: research/ciphertext-size.md
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
  LWE (Regev 2005) \
  · mask: random, independent of the message → can be a seed \
  · body: message under a one-time pad ⟨a, s⟩ that needs the key \
  · no noise → 2048 ciphertexts give the key by Gaussian elimination \
  · adding ciphertexts adds noises; near Δ/2 decryption fails; bootstrapping resets \
  Δ = 2^59 (checked in tfhe 1.8.1, shortint/encoding.rs) \
  Sources: research/ciphertext-size.md
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
  select(c, a, b) = c·a + (1−c)·b: both sides always computed, fresh ciphertext \
  TFHE-rs: pack c next to each 2-bit block (2·block + c fits thanks to carry bits) → lookup "block if c else 0" \
  · two ciphertexts: ≈3 bootstraps per block \
  · plain values (our peak_count): 1 bootstrap of c for the whole result \
  Sources: research/operations.md (tfhe 1.8.1, radix_parallel/cmux.rs)
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

