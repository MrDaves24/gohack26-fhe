# GOHack26: FHE - Usage and limitations
In theory, FHE is the Graal of cryptography and confidential computing. In practice, it's hell.

# Plan
1. Hook (2min) : the marketing of FHE, the magic it can do
2. Refresher (2min) : one slide of math, the homomorphism equeation, noise, bootstrapping
3. Using FHE (5min)
  - Plant a context, show a code we will convert to FHE
  - Go step by step through the code, show the differences, show what we can or cannot do, how to overcome the problem
  - Show were tradeoffs are (size, speed, security) (basically, there's a security floor limiting the minimum, we want to reach this minimum)
4. The bill (5min)
  - FHE is damn slow
  - FHE is damn huge
  - Benchmark, comparison, graphs
5. 3min schemes, how do I pick?
6. Pitfalls (1-2min): no integrity, that's the point. Weird attacks. The solution? Even more noise -> slower
7. Takeaway (1-2min): When FHE is worth, or when to go for TEE, MPC, or ZKP

# Catalogue of annoying things to code in FHE
Plain code	Problem in FHE	Workaround
if secret > x { a } else { b }	can’t branch on an encrypted value	compute both sides, then cond.select(a, b)
while / early break	the number of iterations would reveal data	fixed maximum number of iterations, masking the extra ones
arr[secret_idx]	memory access would reveal the index	compare the index with every position and add up the masked values: O(n) instead of O(1)
sum / count	division by an encrypted value is very expensive	divide by a public value if you can; this goes a long way
u32 that may overflow	wraps silently, and every extra bit costs time	choose the bit width up front
return the filtered list	the length of the output would reveal data	fixed-size output plus a mask, or return only a count
println! for debugging	you can’t see intermediate values	debugging needs the client key, which the server never has

# Whole program:
normal: load data, compute, write output
FHE: generate context, load data, encrypt data, compute, decrypt, write output

# Program context
A smart meter? Because it leaks when you're home and you don't want it. it also allows for a contractual limit.

# The plan
## Phase 0: Settle the unknowns (½ day)

Ask the organizers who usually attends, and what projector, aspect ratio and video connection the room has. That also settles 16:9 versus 4:3.
Pick a TFHE-rs version and stick to it until the talk.
Write the one-sentence thesis on a sticky note, for example “In theory FHE computes anything. Here’s what that costs in practice.” Every slide has to serve it.

## Phase 1: Code (2–3 days) — the biggest part of the work

Plain Rust version of the smart meter scenario, split into named steps.
TFHE-rs version with the same steps, each one written as a clean, self-contained snippet, since the snippets go on your slides.
Timing per step (key generation, encryption, each computation step, decryption), plus the sizes of ciphertexts and keys, written to a CSV or JSON file.
Check that both versions give the same results, so the encrypted version is shown to be correct as well as slow.
Clean it up, add a README and push it to GitHub. That’s what the QR code on the last slide points to.

## Phase 2: Measure (½ day)

Run the benchmarks in release mode, several times, taking the median, and note the hardware and number of cores.
Optionally, also measure scaling for n = 24, 48, 96… if you want a scaling chart.
Look at the results before writing slides. If one step is surprisingly slow or fast, the story adjusts here.

## Phase 3: Research the non-code parts (1 day)

Check the deployments you’ll cite (Apple, Microsoft Edge Password Monitor, Zama) against their current sources.
Confirm the Li & Micciancio citation and one line on the follow-up work.
Gather the scheme-family comparison and a few points for the takeaway (FHE vs. TEE, MPC, ZK).

## Phase 4: Slides (2 days)

Write a skeleton in Typst: every slide’s title and one line of intent, nothing more. Read it through as a story.
Fill in the content in this order: snippets, then pipeline diagram, then benchmark chart (loaded from your CSV), then the rest. Title, “me” and roadmap come last.
Add speaker notes as you go. They’re much easier to write while the content is fresh.

## Phase 5: Rehearse (1–2 days, spread out)

First run-through with a timer. It’ll probably run over, so cut slides rather than talking faster.
Prepare 3–4 likely questions and backup slides for them (Li & Micciancio details, GPU numbers, why not MPC). Put them after the “Thanks” slide.
Do a second run-through with someone listening, a third on your own, and a final check on the real projector or in 4:3.
