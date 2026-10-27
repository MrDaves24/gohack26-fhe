# Fully Homomorphic Encryption (FHE) – Usage and limitations

Talk given at **GOHack26** (30 October 2026) by Pascal Perrenoud ([Codexa](https://codexa.swiss)).

> In theory, FHE is the Holy Grail of cryptography and confidential computing.
> In practice, a long quest.

Not an FHE overview and not a lattice lecture: what it is actually like to build
something with FHE. The talk rewrites ordinary code for FHE snippet by snippet, then
measures the cost in time and size on a small but complete program, a smart meter
computing a daily bill on encrypted readings.

## Headline numbers

Measured on a MacBook Air M4 (fanless, 4 threads, median of 5 runs), with
[TFHE-rs](https://github.com/zama-ai/tfhe-rs) 1.8.1 and its default parameters:

| | Plain Rust | FHE (TFHE-rs) |
|---|---|---|
| `a > b` on two bytes | 0.7 ns, 2 bytes | 41 ms, 132 KB |
| One day of the smart meter (7 steps) | 18 ns | 33 s |
| Daily upload / download | 55 B / 40 B | 3.6 MB / 1.5 MB |
| Server key (sent once) | — | 181 MB |

Plain and FHE outputs are asserted equal on every run. Raw data:
[`bench/results/`](bench/results/).

## What's in the repo

| Path | Content |
|---|---|
| [`bench/`](bench/) | Rust crate: the smart meter in plain Rust ([`plain.rs`](bench/src/plain.rs)) and with TFHE-rs ([`fhe.rs`](bench/src/fhe.rs)), same step names; the harness ([`main.rs`](bench/src/main.rs)) times every step and writes the results |
| [`bench/results/`](bench/results/) | `timings.csv`, `sizes.csv`, `meta.json` (machine, threads, tfhe version, date, runs) |
| [`presentation.typ`](presentation.typ) | The slides (Typst + Touying). Charts and numbers are read from `bench/results/` |
| [`research/`](research/) | Fact-checked notes behind every claim on the slides, each with its sources |
| [`PRESENTING.md`](PRESENTING.md) | Presenting with pdfpc: commands, keys, usual problems |
| [`PLAN.md`](PLAN.md) | The talk plan and every decision taken while preparing it |
| [`CLAUDE.md`](CLAUDE.md) | Instructions for the AI assistant (Claude Code) used to prepare the talk |

## Run the benchmark

Requires Rust (stable). The first build of `tfhe` takes a few minutes.

```sh
cd bench
cargo run --release -- --runs 1             # quick check, ~1 min
RAYON_NUM_THREADS=4 cargo run --release     # 5 runs, ~4 min, writes results/
```

Options: `--runs N`, `--seed S` (another generated day), `--out DIR`.

## Build and present the slides

Requires [Typst](https://typst.app) ≥ 0.15 (packages are fetched on first build) and, to
present, [pdfpc](https://pdfpc.github.io).

```sh
./compile.sh    # → build/presentation-16-9.pdf and .pdfpc (speaker notes)
./present.sh    # rebuilds if needed, starts pdfpc with a 20-minute timer
```

## Research notes

| Note | Topic |
|---|---|
| [`history-and-bottlenecks.md`](research/history-and-bottlenecks.md) | "Holy Grail" quote, FHE generations, memory-bound bootstrapping |
| [`schemes.md`](research/schemes.md) | TFHE vs BFV/BGV vs CKKS |
| [`operations.md`](research/operations.md) | How TFHE builds `+`, `>`, `select`; FHE code as a circuit |
| [`ciphertext-size.md`](research/ciphertext-size.md) | Why an encrypted byte is 66 KB and the server key 181 MB; LWE |
| [`deployments.md`](research/deployments.md) | Apple (Live Caller ID, PIR), Microsoft Edge, Zama |
| [`acceleration.md`](research/acceleration.md) | GPU, FPGA, ASIC: measured vs claimed speed-ups |
| [`attacks.md`](research/attacks.md) | No integrity; IND-CPA<sup>D</sup> key recovery (Li & Micciancio and after) |
| [`alternatives.md`](research/alternatives.md) | FHE vs TEE vs MPC vs ZKP |

## Licence

- Code (`bench/`, scripts): [MIT](LICENSE).
- Slides, speaker notes and research notes: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- The Codexa logo (`assets/codexa-logo.png`) is not covered by either licence.
