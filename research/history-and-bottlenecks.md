# History and bottlenecks: fact-check

Checked 2026-10-13. Quotes are verbatim from the linked source unless marked otherwise.

## Summary (slide-ready)

- **1978 → 2009.** Rivest, Adleman and Dertouzos proposed "privacy homomorphisms" in 1978 ([RAD78](https://people.csail.mit.edu/rivest/pubs/RAD78.pdf)); Gentry built the first FHE scheme in 2009 ([STOC 2009](https://doi.org/10.1145/1536414.1536440)).
- **"Holy Grail" is attributable**: Micciancio, CACM March 2010: FHE "remained a mirage for three decades, the never-to-be-found Holy Grail of cryptography" ([CACM](https://cacm.acm.org/research/technical-perspective-a-first-glimpse-of-cryptographys-holy-grail/)).
- **FHE is memory-bound, not compute-bound**: bootstrapping has "low arithmetic intensity (<1 Op/byte), require[s] large caches (>100 MB), and [is] heavily bound by the main memory bandwidth" ([de Castro et al. 2021](https://arxiv.org/abs/2112.06396)).
- **Keys are huge**: CKKS bootstrapping "requires loading GBs of evaluation keys" ([ARK, MICRO 2022](https://arxiv.org/abs/2205.00922)); our TFHE-rs server key is 181 MB, an order of magnitude above the M4's 16 MB L2 ([bench/results/sizes.csv](../bench/results/sizes.csv)).
- **Ciphertext expansion**: one encrypted `u8` in TFHE-rs is 66 KB, about 66,000× ([sizes.csv](../bench/results/sizes.csv)); batched CKKS/BFV amortises this to roughly 20–100× per slot (derived below).

## A. History and the "Holy Grail"

### A1. Citations

- **Rivest, Adleman, Dertouzos (1978).** R. L. Rivest, L. Adleman, M. L. Dertouzos, "On Data Banks and Privacy Homomorphisms", in R. A. DeMillo, D. P. Dobkin, A. K. Jones, R. J. Lipton (eds.), *Foundations of Secure Computation*, Academic Press, 1978. [PDF](https://people.csail.mit.edu/rivest/pubs/RAD78.pdf).
  - **Page numbers conflict.** Rivest's own BibTeX gives **pp. 165–179** ([RAD78.bib](https://people.csail.mit.edu/rivest/pubs/RAD78.bib.txt)). Gentry's CACM paper and most later papers cite **pp. 169–180** ([Gentry CACM 2010, ref. 5](https://crypto.stanford.edu/craig/easy-fhe.pdf)). The scanned PDF has 11 pages and no visible page numbers. On a slide, cite it without pages.
  - The term they coined: encryption functions "which permit encrypted data to be operated on without preliminary decryption of the operands ... we call 'privacy homomorphisms'" ([PDF, p. 1](https://people.csail.mit.edu/rivest/pubs/RAD78.pdf)). Their example is a loan company that stores its records on a commercial time-sharing service: in effect, the cloud.
- **Gentry, STOC 2009.** Craig Gentry, "Fully homomorphic encryption using ideal lattices", *Proc. 41st ACM Symposium on Theory of Computing (STOC '09)*, pp. 169–178, 2009. DOI [10.1145/1536414.1536440](https://doi.org/10.1145/1536414.1536440) (metadata checked on Crossref).
- **Gentry, PhD thesis.** Craig Gentry, *A Fully Homomorphic Encryption Scheme*, PhD thesis, Stanford University, 2009. [PDF](https://crypto.stanford.edu/craig/craig-thesis.pdf), [page](https://crypto.stanford.edu/craig). It won the ACM Doctoral Dissertation Award ([ACM, June 2010](https://www.acm.org/media-center/2010/june/gentry-wins-acm-doctoral-dissertation-award-for-innovation-in-encryption-technology)).
- **Gentry's accessible version.** C. Gentry, "Computing arbitrary functions of encrypted data", *Communications of the ACM* 53(3):97–105, March 2010. DOI [10.1145/1666420.1666444](https://doi.org/10.1145/1666420.1666444), [PDF](https://crypto.stanford.edu/craig/easy-fhe.pdf). In it Gentry writes that RAD "suggested that fully homomorphic encryption may be possible in 1978, shortly after the invention of the RSA cryptosystem, but were unable to find a secure scheme".

### A2. "Holy Grail" attribution

- **Primary source (verified verbatim).** Daniele Micciancio, "Technical Perspective: A First Glimpse of Cryptography's Holy Grail", *Communications of the ACM* 53(3):96, March 2010. DOI [10.1145/1666420.1666445](https://doi.org/10.1145/1666420.1666445). [Full text](https://cacm.acm.org/research/technical-perspective-a-first-glimpse-of-cryptographys-holy-grail/) (read through its [archived copy](https://web.archive.org/web/20250420102223/https://cacm.acm.org/research/technical-perspective-a-first-glimpse-of-cryptographys-holy-grail/); the live page returns 403 to scripts).
  - "The idea of fully homomorphic encryption schemes was first proposed by Rivest, Adleman, and Dertouzos the late 1970s, but remained a mirage for three decades, the never-to-be-found Holy Grail of cryptography."
  - "Before Gentry's discovery many members of the cryptography research community thought fully homomorphic encryption was impossible to achieve. Now, most cryptographers (me among them) are convinced the Holy Grail exists."
  - This is a CACM "Technical Perspective": the one-page introduction to Gentry's paper, printed in the same issue.
- **IBM press release (June 2009) calling FHE the "holy grail"**: UNVERIFIED. Secondary pages say it did, but the IBM original (`ibm.com/press/.../27840.wss`) could not be retrieved. The coverage I could check ([Network World](https://www.networkworld.com/article/765479/seeing-without-revealing-ibm-touts-encryption-breakthrough.html), [Schneier, July 2009](https://www.schneier.com/blog/archives/2009/07/homomorphic_enc.html)) does not use the phrase. Use Micciancio.
- **Hook bonus (verified).** Schneier, July 2009: "Gentry estimates that performing a Google search with encrypted keywords would increase the amount of computing time by about a trillion" ([blog](https://www.schneier.com/blog/archives/2009/07/homomorphic_enc.html)).
- **Suggested slide line**: *"the never-to-be-found Holy Grail of cryptography" (D. Micciancio, CACM 2010)*.

### A3. Generations (one line)

Gentry 2009 (ideal lattices, bootstrapping) → **2nd gen, BGV/BFV** (RLWE, levelled, SIMD batching, exact integers): BGV [ITCS 2012](https://doi.org/10.1145/2090236.2090262) ([ePrint 2011/277](https://eprint.iacr.org/2011/277)), Brakerski 2012 ([ePrint 2012/078](https://eprint.iacr.org/2012/078)), Fan–Vercauteren 2012 ([ePrint 2012/144](https://eprint.iacr.org/2012/144)) → **3rd gen, GSW/FHEW/TFHE** (fast bootstrapping per gate or small integer): GSW [CRYPTO 2013](https://eprint.iacr.org/2013/340), FHEW [EUROCRYPT 2015](https://doi.org/10.1007/978-3-662-46800-5_24) ("about half a second" per bootstrap), TFHE [ASIACRYPT 2016](https://eprint.iacr.org/2016/870) ("less than 0.1 seconds"; full version in [J. Cryptology](https://eprint.iacr.org/2018/421)) → **4th gen, CKKS** (approximate real or complex numbers, built for ML): [ASIACRYPT 2017](https://eprint.iacr.org/2016/421).
- Venues: Brakerski's is from memory (CRYPTO 2012), UNVERIFIED. FV was only ever published on ePrint. The "generation" labels are a community convention, not a formal one.

## B. Where FHE time goes: memory, not arithmetic

### B1. Memory-bandwidth-bound: sources

- **de Castro, Agrawal, Yazicigil, Chandrakasan, Vaikuntanathan, Juvekar, Joshi**, "Does Fully Homomorphic Encryption Need Compute Acceleration?", [arXiv 2112.06396](https://arxiv.org/abs/2112.06396) (2021). The clearest quote: secure bootstrapping implementations "exhibit a low arithmetic intensity (<1 Op/byte), require large caches (>100 MB), and are heavily bound by the main memory bandwidth". They conclude: "yes, but only after addressing the memory bottleneck!"
- **Jung, Kim, Ahn, Cheon, Lee**, "Over 100x Faster Bootstrapping in Fully Homomorphic Encryption through Memory-centric Optimization with GPUs", *TCHES* 2021(4):114–148, [paper](https://tches.iacr.org/index.php/TCHES/article/view/9062), [ePrint 2021/508](https://eprint.iacr.org/2021/508). Abstract: "the major performance bottleneck is their high main-memory bandwidth requirement, which is exacerbated by leveraging existing optimizations targeted to reduce computation." In the body: "they are not bottlenecked by the limited number of arithmetic units (compute-bound) but by the limited memory bandwidth (memory-bound) on modern GPUs."
- **F1** (Samardzic et al., MICRO 2021), [arXiv 2109.05371](https://arxiv.org/abs/2109.05371): "This organization provides so much compute throughput that data movement becomes the bottleneck. Thus, F1 is primarily designed to minimize data movement."
- **BTS** (Kim et al., ISCA 2022), [arXiv 2112.15479](https://arxiv.org/abs/2112.15479): "bootstrapping requires a significant amount of additional computation and memory bandwidth as well."
- **ARK** (Kim et al., MICRO 2022), [arXiv 2205.00922](https://arxiv.org/abs/2205.00922): "FHE schemes are highly memory-bound. Bootstrapping, in particular, requires loading GBs of evaluation keys and plaintexts from off-chip memory, which makes FHE acceleration fundamentally bottlenecked by the off-chip memory bandwidth."
- **CraterLake** (Samardzic et al., ISCA 2022), [PDF](https://people.csail.mit.edu/sanchez/papers/2022.craterlake.isca.pdf): keyswitching "requires a large auxiliary operand called a keyswitch hint (KSH); the KSH adds pressure on memory bandwidth and on-chip storage." It also gives the overhead: "about 10,000× over unencrypted computation"; "in CPUs, FHE computations are 10,000× to 100,000× slower".
- **SHARP** (Kim et al., ISCA 2023): a follow-up to ARK on word length and data movement. Not quoted here: no primary text retrieved.
- **Scope caveat**: all of these concern **CKKS/BGV-style RLWE bootstrapping**, where a single key-switching key is tens of MB. None of them measures TFHE (the scheme we use) on a CPU. Our own bench could not show memory stalls either (PLAN.md, "Memory-bound (not shown)"). On a slide, say "for CKKS-style FHE, accelerator papers find…", not "our benchmark is memory-bound".

### B2. Key sizes vs caches

| What | Size | Source |
|---|---|---|
| FHEW bootstrapping key | 1 GB | [TFHE abstract](https://eprint.iacr.org/2016/870): "reduce the 1GB bootstrapping key size to 24MB" |
| TFHE (2016) bootstrapping key | 24 MB | same |
| **TFHE-rs 1.8.1 server key (our params)** | **180.6 MB** (60.2 MB compressed) | [bench/results/sizes.csv](../bench/results/sizes.csv), measured 2026-10-13 |
| CKKS keyswitch hint, N=64K, L=60 | 52.5 MB (boosted) vs 1.7 GB (standard) | [CraterLake §3](https://people.csail.mit.edu/sanchez/papers/2022.craterlake.isca.pdf) |
| CKKS bootstrapping, all eval keys | "GBs" | [ARK abstract](https://arxiv.org/abs/2205.00922) |
| Working set needed to cache bootstrapping | ">100 MB" | [de Castro et al.](https://arxiv.org/abs/2112.06396) |

- **Caches for comparison.** Xeon: "24.75 MBs of last-level cache per socket"; V100: "a last-level cache of 6 MBs", "900 GB/s" ([Jung et al.](https://tches.iacr.org/index.php/TCHES/article/view/9062)). Apple M4: 16 MB L2 shared by the P-cores, 4 MB by the E-cores ([Low End Mac](https://lowendmac.com/1234/apple-silicon-m4-chip-specs/), a secondary source; Apple doesn't publish cache sizes, so treat these as UNVERIFIED against Apple).
- Takeaway: our 181 MB server key is about 11× the M4's P-core L2, so every bootstrap streams key material from DRAM.

### B3. Ciphertext expansion

- **TFHE-rs (measured, this repo, [sizes.csv](../bench/results/sizes.csv))**: `FheBool` 16,593 B for 1 bit; `FheUint8` 66,101 B for 1 byte (**~66,000×**); `FheUint16` 132,101 B; `FheUint32` 264,101 B. The size grows linearly with the bit width: TFHE-rs radix ciphertexts are 4 × 2-bit blocks per byte, at about 16.5 KB per block. A day's upload is 3.6 MB.
- **Batched BFV (derived, not quoted)**: the HE Standard's 128-bit table allows log q ≤ 218 at N = 8192 (ternary secret) ([HE Standard v1.1, Table](https://homomorphicencryption.org/wp-content/uploads/2018/11/HomomorphicEncryptionStandardv1.1.pdf)). A fresh ciphertext is 2 · 8192 · 218 bits ≈ 446 KB and holds 8192 slots, so ≈ 55 B/slot. Against a ~20-bit plaintext slot that is **~20×**. Derived by me; check before putting it on a slide.
- **Deep CKKS (derived)**: CraterLake gives "very large ciphertexts (tens of MBs each)", with 20–26 MB as the sweet spot ([CraterLake](https://people.csail.mit.edu/sanchez/papers/2022.craterlake.isca.pdf)). At N = 64K that is 32K slots, so ~800 B/slot against an 8-byte double: **~100×**. Derived.
- Slide framing: TFHE pays ~10⁴–10⁵× per value but computes on each one exactly; batched schemes amortise down to ~10–100× per slot, at the cost of SIMD-only, approximate (CKKS) or levelled arithmetic.
