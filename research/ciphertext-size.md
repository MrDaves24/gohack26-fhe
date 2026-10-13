# Why is an encrypted byte 66 KB?

Likely audience question on the *Bit width* slide. Checked 13 Oct 2026 against the
`tfhe` 1.8.1 source and our own measurements.

## Summary

- An encrypted integer is split into **2-bit blocks**: `FheUint8` = 4 blocks,
  `FheUint16` = 8, `FheUint32` = 16. Size grows linearly with the bit width.
- Each block is one LWE ciphertext of **2049 × 64-bit values = 16 392 bytes**, to carry
  2 bits: a 2048-value random mask plus one body value hiding the message under noise.
- The rest (~100 B per block plus a header) is metadata: versioning, noise level.
- Expansion: ~8 000× per bit. Most of each ciphertext is randomness, which is why
  "compressed" ciphertexts replace the mask with a seed.

## Numbers

Measured with `tfhe::safe_serialization::safe_serialized_size` on one fresh ciphertext
(`bench/src/fhe.rs`, function `sizes`), written to `bench/results/sizes.csv`.

| Type | Blocks | Blocks × 16 392 B | Measured | Remainder |
|---|---|---|---|---|
| `FheBool` | 1 | 16 392 | 16 593 | 201 B |
| `FheUint8` | 4 | 65 568 | 66 101 | 533 B |
| `FheUint16` | 8 | 131 136 | 132 101 | 965 B |
| `FheUint32` | 16 | 262 272 | 264 101 | 1 829 B |

## Where each factor comes from

- Default parameters: `ConfigBuilder::default()` uses
  `PARAM_MESSAGE_2_CARRY_2_KS_PBS_TUNIFORM_2M128`, an alias of
  `V1_8_…` → `V1_4_PARAM_MESSAGE_2_CARRY_2_KS_PBS_TUNIFORM_2M128`
  ([aliases.rs](https://docs.rs/crate/tfhe/1.8.1/source/src/shortint/parameters/aliases.rs),
  [v1_8 ks_pbs.rs](https://docs.rs/crate/tfhe/1.8.1/source/src/shortint/parameters/v1_8/classic/tuniform/p_fail_2_minus_128/ks_pbs.rs)).
- Its values ([v1_4 ks_pbs.rs](https://docs.rs/crate/tfhe/1.8.1/source/src/shortint/parameters/v1_4/classic/tuniform/p_fail_2_minus_128/ks_pbs.rs)):
  - `message_modulus: 4`, `carry_modulus: 4` → 2 message bits + 2 carry bits per block.
  - `glwe_dimension: 1`, `polynomial_size: 2048` → ciphertexts under the big key have
    an LWE dimension of 1 × 2048 = 2048, plus 1 body value.
  - `ciphertext_modulus: CiphertextModulus::new_native()` → modulus 2⁶⁴, one `u64` per value.
  - `lwe_dimension: 918` is the small key, used only inside bootstrapping (after key
    switching); ciphertexts at rest and on the wire are under the big key.
- The measured sizes match 4/8/16 blocks × 16 392 B, which confirms the block counts.
- Compressed ciphertexts are seeded: `CompressedRadixCiphertext::Seeded` holds
  `SeededLweCiphertext<u64>` blocks
  ([integers/unsigned/compressed.rs](https://docs.rs/crate/tfhe/1.8.1/source/src/high_level_api/integers/unsigned/compressed.rs),
  [shortint/ciphertext/compressed.rs](https://docs.rs/crate/tfhe/1.8.1/source/src/shortint/ciphertext/compressed.rs)).
  Their size is not measured yet (see "Could do" in `PLAN.md`).

## How one block is encrypted and decrypted (LWE)

TFHE blocks are LWE ciphertexts ("Learning With Errors",
[Regev, STOC 2005, pp. 84–93](https://doi.org/10.1145/1060590.1060603); TFHE:
[Chillotti et al., ePrint 2018/421](https://eprint.iacr.org/2018/421)).

- **Secret key** `s`: 2048 bits, only on the client. TFHE-rs generates binary keys
  (`allocate_and_generate_new_binary_lwe_secret_key`,
  [client_key/atomic_pattern/standard.rs](https://docs.rs/crate/tfhe/1.8.1/source/src/shortint/client_key/atomic_pattern/standard.rs)).
- **Encrypt** a message `m` (2 message bits + 2 carry bits):
  1. mask `a` = 2048 random 64-bit values;
  2. small random noise `e`;
  3. body `b = ⟨a, s⟩ + Δ·m + e mod 2⁶⁴`. Ciphertext = `(a, b)`.
- **Δ = 2⁵⁹** for these parameters: `compute_delta` returns
  `(1 << (64 − 1 − padding)) / (message_modulus × carry_modulus) × 2` = 2⁶²/16 × 2
  ([shortint/encoding.rs](https://docs.rs/crate/tfhe/1.8.1/source/src/shortint/encoding.rs)). The message sits in the top bits:
  1 padding bit, 2 carry bits, 2 message bits, then 59 bits of room for the noise.
- **Decrypt**: `b − ⟨a, s⟩ = Δ·m + e`, then round to the nearest multiple of Δ
  (`decode`: `divide_round(value, delta)`, same file). Works while |e| < Δ/2.
- **Why it is secure**: the mask is independent of the message (so it can be sent as a
  seed); the body is the message under a one-time pad `⟨a, s⟩` that needs the key.
  Without noise, each ciphertext is a linear equation in `s` and 2048 of them give the
  key by Gaussian elimination; with noise, recovering `s` is the LWE problem, believed
  hard, also for quantum computers (Regev 2005).
- **Why noise grows**: adding ciphertexts adds the bodies and the noises
  (`e₁ + e₂`). Near Δ/2, rounding gives a wrong message; bootstrapping resets the noise.
- **Why carry bits**: `m₁ + m₂` can exceed 2 bits; the 2 carry bits absorb it before
  it reaches the padding bit or the noise.
- **Why only 2 bits per block**: bootstrapping evaluates a lookup table whose cost grows
  with the bits per block (4.55 ms at 2 bits vs 773 ms at 8 bits, see
  `research/schemes.md`).
