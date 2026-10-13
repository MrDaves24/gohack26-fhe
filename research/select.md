# How `select` works

Backup slide "How does select work?". Checked 13 Oct 2026 against the `tfhe` 1.8.1
source, [integer/server_key/radix_parallel/cmux.rs](https://docs.rs/crate/tfhe/1.8.1/source/src/integer/server_key/radix_parallel/cmux.rs).

## Summary

- `select(c, a, b)` is the arithmetic form of a branch: `c·a + (1 − c)·b`. Both `a`
  and `b` are always computed; the result is a fresh ciphertext that does not reveal
  which side it came from (the doc says it "won't exactly be true_ct or false_ct").
- TFHE-rs does it per 2-bit block with **programmable bootstrapping**: pack the condition
  next to the value in one block, then bootstrap with a lookup table "value if c, else 0".
- Cost: about 3 bootstraps per block with two ciphertexts; a single multi-output
  bootstrap of `c` when both sides are plain values (our `peak_count`, `budget_hour`,
  `tariff_lookup`).

## Two ciphertexts: `if_then_else(c, a, b)`

`unchecked_programmable_if_then_else_parallelized`:
1. `zero_out_if` on a copy of `a` (zero it if `c` is false) and of `b` (zero it if
   `c` is true), in parallel. For each block: `x = block × 2 + c` (`condition_mod` =
   degree + 1 = 2 for a boolean), then `apply_lookup_table` with
   `f(x) = predicate(x mod 2) ? 0 : x / 2`. One bootstrap per block.
   A 2-bit block times 2 plus 1 is at most 7, which fits in the 4-bit block (2 message +
   2 carry bits): this is what the carry space is for.
2. Add the two results block by block (one of them is all zeros), then
   `message_extract` cleans the carries: one more bootstrap per block.

So ≈ 3 bootstraps per block, e.g. 12 for an `FheUint8` (4 blocks).

## Plain values: `FheUint8::select(&c, 1u8, 0u8)`

`scalar_if_then_else_parallelized`: the result depends only on `c`, so each output
block is a lookup table of `c` alone (`condition == 1 ? true_block : false_block`).
With `generate_many_lookup_table` one bootstrap of `c` yields up to
`message_modulus × carry_modulus / 2` = 8 output blocks at once. An `FheUint8` result
(4 blocks) costs one bootstrap.

## Why it matters for the talk

- It is the workaround behind three snippets (branch, loop, secret index).
- It is cheap only relative to the rest: every call is at least one bootstrap.
- The real magic is the **programmable** bootstrap: it resets the noise *and* applies
  any function on a small block (Chillotti, Joye & Paillier,
  [ePrint 2021/091](https://eprint.iacr.org/2021/091), see `research/schemes.md`).
