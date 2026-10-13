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
