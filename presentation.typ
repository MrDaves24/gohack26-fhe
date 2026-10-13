#import "@preview/touying:0.8.0": *
#import themes.metropolis: *

// Codexa brand colors, sampled from the press logo (codexa.swiss/fr/press).
#let navy = rgb("#012473")
#let cyan = rgb("#51C2F8")
// Body text: the site's "coal".
#let coal = rgb("#222222")

// Progress bar along the bottom edge of the gray header, full page width. The header
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

== About me

#slide(composer: (3fr, 2fr))[
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

#outline-slide(title: [Roadmap], level: 1, numbered: (false,), vspace: (0em,))

= FHE in one slide

== Refresher

= Writing FHE code

== Init

== Branching

== Loops

== Secret index

== Division

== Bit width

== Variable output

= Putting it together

== Smart meter

= The bill

== Timings

== Where the time goes

= Choosing a scheme

== Schemes & deployments

= Pitfalls

== Weird pitfalls

= Takeaway

== When is FHE worth it?

#focus-slide[
  Thanks for your attention

  #text(size: 0.6em)[Any question?]
]

#show: appendix

#heading(depth: 1, outlined: false)[Backup]

== Li & Micciancio

== Scheme comparison

== Why not MPC or a TEE?
