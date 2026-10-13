# FHE schemes: TFHE vs BFV/BGV vs CKKS (fact check, 2026-10-13)

## Summary (slide-ready)

- **TFHE** evaluates any function of a *small* encrypted value (lookup table) while it refreshes the noise: "programmable bootstrapping". One PBS costs milliseconds, and grows fast with precision (2 bits: 4.55 ms, 8 bits: 773 ms on a 192-core server). [TFHE-rs docs](https://docs.zama.org/tfhe-rs/get-started/security-and-cryptography), [PBS benchmarks](https://docs.zama.org/tfhe-rs/get-started/benchmarks/cpu/cpu-programmable-bootstrapping)
- **TFHE-rs integers are radix chains of 2-bit blocks**: an `FheUint32` is 16 blocks, so a 32-bit add needs carry propagation through bootstraps (40.9 ms on 192 cores; ~0.28 s per add in our laptop run). [tfhe 1.8.1 source](https://docs.rs/crate/tfhe/1.8.1/source/src/high_level_api/integers/mod.rs), [integer benchmarks](https://docs.zama.org/tfhe-rs/get-started/benchmarks/cpu/cpu-integer-operations)
- **BFV/BGV** pack thousands of exact integers in one ciphertext (8192 slots at N=8192): one addition adds them all; mixing slots needs rotations, each about as costly as a multiplication. [SEAL example](https://github.com/microsoft/SEAL/blob/main/native/examples/2_encoders.cpp), [SEAL 2.3.1 manual §7](https://www.microsoft.com/en-us/research/wp-content/uploads/2017/11/sealmanual-2-3-1.pdf)
- **CKKS** does the same on approximate reals (N/2 slots), the scheme of choice for encrypted ML (ResNet-110); comparisons are polynomial approximations of sign: slow and approximate. [CKKS](https://eprint.iacr.org/2016/421), [Lee et al.](https://eprint.iacr.org/2021/1688), [Cheon-Kim-Kim](https://eprint.iacr.org/2019/1234)
- **No best scheme**: a 2025 CKKS-vs-TFHE study finds CKKS faster on most parallel operations but TFHE faster on comparisons; libraries now switch schemes mid-computation (OpenFHE CKKS↔FHEW). [Krüger et al.](https://eprint.iacr.org/2025/1460), [OpenFHE scheme switching](https://github.com/openfheorg/openfhe-development/blob/v1.1.0/src/pke/examples/SCHEME_SWITCHING_CAPABILITY.md)

| Scheme | Data type | Strengths | Weaknesses | Sources |
|---|---|---|---|---|
| TFHE (CGGI) | small integers / bits (TFHE-rs: 2-bit blocks chained into `FheUint8..128`) | any function via lookup table (PBS); comparisons, branches-as-select; unlimited depth | one value per ciphertext; every non-linear op (and carries) costs PBS; cost explodes with block precision | [TFHE](https://eprint.iacr.org/2018/421), [PBS](https://eprint.iacr.org/2021/091), [TFHE-rs docs](https://docs.zama.org/tfhe-rs/get-started/security-and-cryptography) |
| BFV / BGV | exact integers mod t, vectors of N slots | SIMD: one add/mult acts on thousands of slots; cheap add | rotations cost a key switch; comparisons need deep polynomial circuits; values must not wrap mod t | [FV](https://eprint.iacr.org/2012/144), [BGV](https://eprint.iacr.org/2011/277), [SIMD](https://eprint.iacr.org/2011/133), [SEAL manual](https://www.microsoft.com/en-us/research/wp-content/uploads/2017/11/sealmanual-2-3-1.pdf) |
| CKKS | approximate real/complex, N/2 slots | fast vector arithmetic on reals; ML inference | results approximate; comparison = approximate sign polynomial; bootstrapping expensive | [CKKS](https://eprint.iacr.org/2016/421), [Cheon-Kim-Kim](https://eprint.iacr.org/2019/1234), [FIDESlib bench](https://arxiv.org/pdf/2507.04775) |

## 1. TFHE and programmable bootstrapping

- Original paper: I. Chillotti, N. Gama, M. Georgieva, M. Izabachène, "TFHE: Fast Fully Homomorphic Encryption over the Torus", Journal of Cryptology (full version of Asiacrypt 2016 and 2017 papers). Abstract: bootstrapping cut "from 690ms to 13ms single core", bootstrapping key from 1 GB to 16 MB. [ePrint 2018/421](https://eprint.iacr.org/2018/421)
- Bootstrap per gate: in gate-level TFHE "the bootstrapping procedure is instrumental in the correct evaluation of homomorphic logic gates", i.e. one bootstrap per gate except NOT. [Gouert et al., PoPETs 2023](https://petsymposium.org/popets/2023/popets-2023-0075.pdf)
- Programmable bootstrapping: I. Chillotti, M. Joye, P. Paillier, "Programmable Bootstrapping Enables Efficient Homomorphic Inference of Deep Neural Networks", CSCML 2021: evaluates "any function of a ciphertext, with a controlled level of noise". [ePrint 2021/091](https://eprint.iacr.org/2021/091)
- TFHE-rs phrasing: PBS "allows any function to be homomorphically computed over an encrypted input, while also reducing the noise"; functions are lookup tables; additions are cheap (leveled), PBS is "far more expensive"; default parameters have p_error ≤ 2^-128. [TFHE-rs: security and cryptography](https://docs.zama.org/tfhe-rs/get-started/security-and-cryptography)
- PBS cost vs precision (TFHE-rs docs, p_fail 2^-128, AWS hpc8a.96xlarge, tfhe-fft + AVX-512; latest docs, not pinned to 1.8.1): [PBS benchmarks](https://docs.zama.org/tfhe-rs/get-started/benchmarks/cpu/cpu-programmable-bootstrapping)

  | precision | 2 bits | 4 bits | 6 bits | 8 bits |
  |---|---|---|---|---|
  | PBS | 4.55 ms | 5.64 ms | 52.9 ms | 773 ms |
  | KS + PBS | 5.72 ms | 7.28 ms | 60.8 ms | 870 ms |

  This is why integers are built from small blocks: going from 4 to 8 bits costs ~140x per bootstrap.
- Radix integers in tfhe 1.8.1: the high-level default config is `PARAM_MESSAGE_2_CARRY_2_KS_PBS_TUNIFORM_2M128` (2 message bits + 2 carry bits per block) [inner.rs](https://docs.rs/crate/tfhe/1.8.1/source/src/high_level_api/keys/inner.rs), and `num_blocks = num_bits / log2(message_modulus)` [integers/mod.rs](https://docs.rs/crate/tfhe/1.8.1/source/src/high_level_api/integers/mod.rs) → `FheUint16` = 8 blocks, `FheUint32` = 16 blocks. Docs example: "8-bit integers ... using 4 shortint blocks that store 2 bits of message each". [Integer API](https://docs.zama.org/tfhe-rs/references/fine-grained-apis/integer)

## 2. BFV / BGV

- BFV: J. Fan, F. Vercauteren, "Somewhat Practical Fully Homomorphic Encryption" (Brakerski's scheme ported to Ring-LWE). [ePrint 2012/144](https://eprint.iacr.org/2012/144)
- BGV: Z. Brakerski, C. Gentry, V. Vaikuntanathan, "Fully Homomorphic Encryption without Bootstrapping" (leveled FHE; introduces batching to reduce per-gate cost for wide circuits). [ePrint 2011/277](https://eprint.iacr.org/2011/277)
- SIMD batching: N. P. Smart, F. Vercauteren, "Fully Homomorphic SIMD Operations". [ePrint 2011/133](https://eprint.iacr.org/2011/133)
- Slots: in SEAL BFV "the total number of batching slots equals the poly_modulus_degree, N", arranged as a 2 × N/2 matrix; with N = 8192 one operation acts "simultaneously in all 8192 slots". [SEAL 2_encoders.cpp](https://github.com/microsoft/SEAL/blob/main/native/examples/2_encoders.cpp) So N = 16384 → 16384 slots.
- Batching = n slot-wise additions (resp. multiplications) mod t "at the cost of one single addition (resp. multiplication)". Rotations are Galois automorphisms; a rotation costs "essentially the same as that of relinearization", and power-of-2 steps cost one relinearization each. Values must never wrap mod t. [SEAL 2.3.1 manual, §7](https://www.microsoft.com/en-us/research/wp-content/uploads/2017/11/sealmanual-2-3-1.pdf)
- Summing slots is the expensive part: "If the slots need to be mixed ... (such as the need to sum all of the slots together), slot-wise rotations must be executed", with high memory and time overheads. [Gouert et al., PoPETs 2023](https://petsymposium.org/popets/2023/popets-2023-0075.pdf)
- Comparisons: costly (deep polynomial circuits), but **with slot packing they can match TFHE**: Iliashenko & Zucca (PoPETs 2021, HElib) report "a similar performance as ... TFHE in basic comparison tasks", "comparing 64-bit integers in 11 milliseconds", min of 64 32-bit integers in 9.5 s. [ePrint 2021/315](https://eprint.iacr.org/2021/315)

## 3. CKKS

- J. H. Cheon, A. Kim, M. Kim, Y. Song, "Homomorphic Encryption for Arithmetic of Approximate Numbers", ASIACRYPT 2017: approximate addition/multiplication with rescaling; batching via canonical embedding into complex vectors; precision loss "at most one more bit" than plain floating point. [ePrint 2016/421](https://eprint.iacr.org/2016/421)
- Slots: "In CKKS the number of slots is poly_modulus_degree / 2 and each slot encodes one real or complex number." [SEAL 2_encoders.cpp](https://github.com/microsoft/SEAL/blob/main/native/examples/2_encoders.cpp)
- ML inference: ResNet-20 to ResNet-110 on RNS-CKKS with bootstrapping (Lee et al., ICML 2022). [ePrint 2021/1688](https://eprint.iacr.org/2021/1688)
- Comparison = composite polynomial approximation of the sign function, complexity Θ(log 1/ε) + Θ(log α); 20-bit comparison in 1.43 ms *amortized* over slots (Cheon, Kim, Kim, ASIACRYPT 2020). Approximate by construction, and needs depth (hence bootstraps). [ePrint 2019/1234](https://eprint.iacr.org/2019/1234)
- CKKS vs TFHE head-to-head on 65,536 32-bit integers: "CKKS outperforms TFHE in most operations", TFHE's advantage is fast bootstrapping, which shows on comparisons; CKKS preferred when the work parallelizes (Krüger, Moriya, Schoop, preprint 2025). [ePrint 2025/1460](https://eprint.iacr.org/2025/1460) (abstract only; the PDF is behind a bot check, numbers not read)

## 4. Summing N values: batching vs TFHE

- **Batched (BFV/CKKS)**: put the N values in slots of one ciphertext, then rotate-and-add log2(N) times (rotate by N/2, N/4, ..., 1). 24 hours → pad to 32 → 5 rotations + 5 additions. Rotation cost ≈ relinearization ([SEAL manual](https://www.microsoft.com/en-us/research/wp-content/uploads/2017/11/sealmanual-2-3-1.pdf)). The other slots compute in parallel for free: N=2^16 CKKS has 32768 slots = 1024 meter-days of 32 slots each (our arithmetic).
- **TFHE-rs**: N-1 (here N, from a trivial zero) sequential `FheUint32` additions, each a carry chain over 16 blocks. Each add is a bootstrapped operation; no slot packing.
- Published per-operation numbers:

  | Library, op | Params | Hardware | Time | Source |
  |---|---|---|---|---|
  | OpenFHE CKKS HAdd | N=2^16, L=29, single thread | AMD Ryzen 9 7900 | 7.84 ms | [FIDESlib, Table V](https://arxiv.org/pdf/2507.04775) |
  | OpenFHE CKKS HRotate | same | same | 370.71 ms | same |
  | OpenFHE CKKS HRotate, HEXL, 24 threads | same | same | 105.30 ms | same |
  | OpenFHE CKKS EvalAdd | N 2^13–2^17, depth 10–20 | i9-13900K / Ryzen 9 7950X | "about 2 ms" | [CryptOracle](https://arxiv.org/html/2510.03565) |
  | TFHE-rs `FheUint32` add | 2-bit blocks, p_fail 2^-128 | AWS hpc8a.96xlarge (2× 96-core EPYC 9R45) | 40.9 ms | [TFHE-rs integer bench](https://docs.zama.org/tfhe-rs/get-started/benchmarks/cpu/cpu-integer-operations) |
  | TFHE-rs `FheUint32` gt / eq | same | same | 35.0 / 26.0 ms | same |
  | TFHE-rs 1.8.1 `total` (24 casts+adds, FheUint32) | default params | MacBook Air M4, 4 threads, median of 5 | 6.8 s (~0.28 s per add) | `bench/results/timings.csv` (ours) |

- Order of magnitude for the slide (our arithmetic from the rows above, heavy bootstrappable CKKS params, single thread): 5 × (371 + 8) ms ≈ **1.9 s for 1024 meter-days at once ≈ 2 ms per meter-day**, vs **6.8 s per meter-day** in our TFHE run: over 3 orders of magnitude in throughput. Latency for a single day is not better unless parameters are smaller.
- UNVERIFIED: with small leveled parameters (N=8192, no bootstrapping) a rotation should take low single-digit ms on a laptop; no primary source with stated hardware found. Measuring it (PLAN stretch: OpenFHE) would settle it.
- Caveat for BFV: t must exceed the max sum (24 × 65535 ≈ 1.6 M, so 65537 is too small) and be a batching-friendly prime. [SEAL manual](https://www.microsoft.com/en-us/research/wp-content/uploads/2017/11/sealmanual-2-3-1.pdf)

## 5. Scheme switching

- CHIMERA (Boura, Gama, Georgieva, Jetchev): unifies TFHE, B/FV and HEAAN (CKKS) plaintext spaces and switches between them; published at NutMic 2019. [ePrint 2018/758](https://eprint.iacr.org/2018/758)
- PEGASUS (Lu, Huang, Hong, Ma, Qu, IEEE S&P 2021): switches packed CKKS ↔ FHEW without decryption, arithmetic in CKKS, lookup tables in FHEW; conversion key 80 GB → 12 MB. [ePrint 2020/1606](https://eprint.iacr.org/2020/1606)
- OpenFHE: `EvalCKKStoFHEW` / `EvalFHEWtoCKKS`, comparisons and argmin/argmax via FHEW; marked experimental, CKKS↔FHEW only, large memory for many slots. [OpenFHE SCHEME_SWITCHING_CAPABILITY.md](https://github.com/openfheorg/openfhe-development/blob/v1.1.0/src/pke/examples/SCHEME_SWITCHING_CAPABILITY.md)
