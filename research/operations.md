# How TFHE operations are built

Backup slide "How does select work?" and one line of the Refresher. Checked 13 Oct 2026
against the `tfhe` 1.8.1 source.

## Two primitives

TFHE has only two real moves; every integer operation is built from them:

1. **Cheap linear operations** on ciphertexts: add two ciphertexts, multiply one by a
   small public integer (`unchecked_add_assign`, `unchecked_scalar_mul`). Arithmetic on
   the 2049 values, no bootstrap, but the noise adds up.
2. **Programmable bootstrap** (`apply_lookup_table`): applies any function to one
   4-bit block (2 message + 2 carry bits) through a lookup table, and resets the noise.
   Milliseconds each (`research/schemes.md`).

The pattern everywhere: pack several small values into one block with linear operations,
then one lookup table computes the function of all of them. The cost of an operation is
roughly its number of bootstraps, so it grows with the number of blocks (the bit width).

## `select`

Source: [integer/server_key/radix_parallel/cmux.rs](https://docs.rs/crate/tfhe/1.8.1/source/src/integer/server_key/radix_parallel/cmux.rs).

- `select(c, a, b)` is the arithmetic form of a branch: `c·a + (1 − c)·b`. Both `a`
  and `b` are always computed; the result is a fresh ciphertext that does not reveal
  which side it came from (the doc says it "won't exactly be true_ct or false_ct").
- TFHE-rs does it per 2-bit block with **programmable bootstrapping**: pack the condition
  next to the value in one block, then bootstrap with a lookup table "value if c, else 0".
- Cost: about 3 bootstraps per block with two ciphertexts; a single multi-output
  bootstrap of `c` when both sides are plain values (our `peak_count`, `budget_hour`,
  `tariff_lookup`).

### Two ciphertexts: `if_then_else(c, a, b)`

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

### Plain values: `FheUint8::select(&c, 1u8, 0u8)`

`scalar_if_then_else_parallelized`: the result depends only on `c`, so each output
block is a lookup table of `c` alone (`condition == 1 ? true_block : false_block`).
With `generate_many_lookup_table` one bootstrap of `c` yields up to
`message_modulus × carry_modulus / 2` = 8 output blocks at once. An `FheUint8` result
(4 blocks) costs one bootstrap.

### Why it matters for the talk

- It is the workaround behind three snippets (branch, loop, secret index).
- It is cheap only relative to the rest: every call is at least one bootstrap.
- The real magic is the **programmable** bootstrap: it resets the noise *and* applies
  any function on a small block (Chillotti, Joye & Paillier,
  [ePrint 2021/091](https://eprint.iacr.org/2021/091), see `research/schemes.md`).

## `gt` (and every comparison)

Source: [integer/server_key/comparator.rs](https://docs.rs/crate/tfhe/1.8.1/source/src/integer/server_key/comparator.rs).
For unsigned integers with carry_modulus ≥ message_modulus (our case):

1. **Pack** pairs of 2-bit blocks into one 4-bit block (`pack_block_chunk`: high × 4 +
   low), cleaned with an identity lookup table. An `FheUint8` (4 blocks) becomes 2
   packed blocks per operand.
2. **Compare** each packed pair: `compare_block_assign` uses `sign_lut` ("sign of
   (a − b)") and returns 0 = less, 1 = equal, 2 = greater.
3. **Reduce** the signs as a tree (`reduce_signs`): pack `high_sign × 4 + low_sign` and
   apply `reduce_two_orderings_function`: "if the high sign is *equal*, take the low
   one, else the high one".
4. **Final** lookup maps the sign to the result (`gt`: sign == 2).

About 7 bootstraps for an `FheUint8` (4 packing + 2 compare + 1 final); our own count
from the code, not measured. Consistent with the measured 41 ms for `gt_u8` at a few ms
per bootstrap.

## Addition: why `total` is slow

Source: [integer/server_key/radix_parallel/add.rs](https://docs.rs/crate/tfhe/1.8.1/source/src/integer/server_key/radix_parallel/add.rs).
Adding two integers adds the blocks (linear, cheap), but each block's result can overflow
into its carry bits; `add_assign_with_carry_parallelized` and `full_propagate_parallelized`
move the carries to the next block with lookup tables. So "just additions" on 16-block
`FheUint32` values still cost many bootstraps.

TFHE-rs also has a dedicated multi-operand sum (`sum_ciphertexts_parallelized` in
[sum.rs](https://docs.rs/crate/tfhe/1.8.1/source/src/integer/server_key/radix_parallel/sum.rs), exposed as `std::iter::Sum` for
`FheUint` in [high_level_api/integers/unsigned/ops.rs](https://docs.rs/crate/tfhe/1.8.1/source/src/high_level_api/integers/unsigned/ops.rs)),
a candidate for the "naive vs optimized" could-do in `PLAN.md`. Not measured.

## FHE code is a circuit (checked 2026-10-17)

- The server cannot see any value, so nothing may depend on the data except the values
  themselves: no data-dependent branches, loop counts, memory addresses or output sizes.
  That is a data-oblivious *circuit*, the same discipline as hardware design (HDL / FPGA):
  `if` → multiplexer (`select`), loops → unrolled with a fixed count, `table[i]` → mux over
  all entries, fixed widths, fixed outputs.
- FHE is defined as evaluating circuits: Gentry, "Fully homomorphic encryption using ideal
  lattices", STOC 2009 ([DOI 10.1145/1536414.1536440](https://doi.org/10.1145/1536414.1536440)),
  see `research/history-and-bottlenecks.md`. Gate-level TFHE bootstraps once per logic gate
  ([Gouert et al., PoPETs 2023](https://petsymposium.org/popets/2023/popets-2023-0075.pdf),
  see `research/schemes.md`).
- Google's FHE transpiler turns C++ into FHE code through a hardware synthesis toolchain:
  "Our transpiler builds on Google's open-source XLS SDK … and uses an off-the-shelf FHE
  library, TFHE" (Gorantala et al., "A General Purpose Transpiler for Fully Homomorphic
  Encryption", 2021, [arXiv 2106.07893](https://arxiv.org/abs/2106.07893)). XLS is Google's
  high-level synthesis toolkit for hardware ([github.com/google/xls](https://github.com/google/xls)).
- The transpiler's repository now points to its successor, **HEIR**, an MLIR-based FHE
  compiler that "support[s] multiple FHE schemes and high-performance backends"
  ([repo README](https://github.com/google/fully-homomorphic-encryption), [HEIR](https://github.com/google/heir)).
- Zama's equivalent: Concrete, "TFHE Compiler that converts python programs into FHE equivalent" ([github.com/zama-ai/concrete](https://github.com/zama-ai/concrete)).
- Difference with an FPGA: a gate costs nanoseconds in hardware, a bootstrap costs
  milliseconds (`research/schemes.md`): same design rules, far slower gates.
