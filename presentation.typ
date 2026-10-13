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

== Branching

#speaker-note[
  `if` on a secret doesn't compile (`FheBool` is not `bool`): compute both sides, then select.
]

== Loops

#speaker-note[
  No early exit, because the number of iterations would leak:
  loop the maximum, or rethink the algorithm (`budget_hour`).
]

== Secret index

#speaker-note[
  `TARIFFS[tier]` would leak through memory access: visit every slot. O(1) becomes O(n).
]

== Division

#speaker-note[Divide by a public 24: 2.1 s. By an encrypted 24: 15.7 s. Same result.]

== Bit width

#speaker-note[Choose widths up front: 1 byte becomes 66 KB, and every bit costs time.]

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
