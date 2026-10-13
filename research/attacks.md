# Weird pitfalls: no integrity, and shared decryptions leak the key

Checked 2026-10-13. Sources are linked inline. "UNVERIFIED" marks what I could not confirm from a primary source.

## Summary (slide-ready)

- **Sharing a decryption can leak the key.** Li & Micciancio (EUROCRYPT 2021) recovered the full CKKS secret key from decryption results, against HEAAN, SEAL, HElib and PALISADE. Standard IND-CPA does not cover this; they defined **IND-CPA^D**. ([ePrint 2020/1533](https://eprint.iacr.org/2020/1533))
- **"Exact" schemes are hit too (2024).** BFV, BGV and TFHE leak the key through rare **decryption failures**: CRYPTO 2024 ([ePrint 2024/116](https://eprint.iacr.org/2024/116)) and ACM CCS 2024 ([ePrint 2024/127](https://eprint.iacr.org/2024/127)). Full key recovery in under an hour on a laptop for several libraries ([ePrint 2024/116](https://eprint.iacr.org/2024/116)).
- **TFHE-rs's answer: make failures astronomically rare.** In TFHE-rs 0.8 the default failure probability was 2^-40, chosen for IND-CPA only ([docs 0.8](https://docs.zama.org/tfhe-rs/0.8/get-started/security_and_cryptography)). Since v1.0 (Feb 2025) it is ≤ 2^-128, which Zama says makes it resilient in the IND-CPA^D model ([docs](https://docs.zama.org/tfhe-rs/get-started/security-and-cryptography), [blog](https://www.zama.org/post/tfhe-rs-v1-0-stable-cpu-backend)). Our 1.8.1 default is `PARAM_MESSAGE_2_CARRY_2_KS_PBS_TUNIFORM_2M128` (checked in the crate source).
- **No integrity: the server can return anything.** The ciphertexts are malleable by design, which is how the server computes on them. So a malicious server can return a wrong result, or tamper with ciphertexts to run key-recovery attacks. Verifiable FHE is still a research topic ([Viand et al., arXiv 2301.07041](https://arxiv.org/abs/2301.07041)).
- **The fix costs.** Noise flooding needs bigger parameters, or for CKKS in OpenFHE it means running the computation twice and adding about 30 bits of noise ([Bernard et al., ePrint 2024/1718](https://eprint.iacr.org/2024/1718), [OpenFHE forum](https://openfhe.discourse.group/t/in-ckks-does-openfhe-always-add-the-noise-before-decoding/1926)).

## 1. Li & Micciancio, EUROCRYPT 2021

- **Citation:** Baiyu Li, Daniele Micciancio, "On the Security of Homomorphic Encryption on Approximate Numbers", EUROCRYPT 2021, LNCS 12696, pp. 648–677. [ePrint 2020/1533](https://eprint.iacr.org/2020/1533), [Springer](https://link.springer.com/chapter/10.1007/978-3-030-77870-5_23).
- **IND-CPA^D:** this is IND-CPA plus a decryption oracle that only answers for ciphertexts whose plaintext the attacker already knows: the results of honest computations on its chosen inputs. It models a "passive" setting where decryption results are shared, for example a hospital-data aggregation service that publishes statistics. The paper first called it IND-CPA+ and notes that "IND-CPA-D" is an alternative name ([ePrint 2020/1533](https://eprint.iacr.org/2020/1533)). For schemes with perfect correctness, IND-CPA^D is equivalent to IND-CPA ([OpenFHE "Making CKKS more secure"](https://openfhe.org/security-of-ckks/)).
- **Attack:** CKKS decryption returns m + e, so the error e travels with the result. Each shared decryption gives a linear equation in the secret key. Collecting enough of them gives the key by linear algebra, in polynomial time, "with high probability and very modest running times" ([ePrint 2020/1533](https://eprint.iacr.org/2020/1533)).
- **Libraries tested:** HEAAN 2.1, RNS-HEAAN, PALISADE 1.10.4, SEAL 3.5 and HElib 1.1.0, all vulnerable. The authors stress this is "not to an implementation bug" but a gap in the security definition (paper text, Sect. 1 and 5, [ePrint 2020/1533](https://eprint.iacr.org/2020/1533)).
- **Countermeasures the paper proposes (Sect. 6):**
  - Adding fresh Gaussian noise at decryption is not enough: averaging repeated decryptions removes it.
  - Deterministic noise (a PRF of the ciphertext), i.e. noise flooding. Unbounded IND-CPA^D "requires a superpolynomial modulus", so it may be impractical. Only a bounded number of queries looks feasible.
  - Exact decryption by rounding.
- **How the libraries responded:**
  - PALISADE/OpenFHE: Gaussian-noise CKKS in PALISADE v1.10.6 ([OpenFHE](https://openfhe.org/security-of-ckks/)). OpenFHE later added a provable `NOISE_FLOODING_DECRYPT` mode. The default fixed-noise mode does **not** achieve provable IND-CPA^D ([OpenFHE security notes](https://openfhe-development.readthedocs.io/en/latest/sphinx_rsts/intro/security.html)).
  - HEaaN shipped an updated version as its countermeasure. Cheon, Hong and Kim also review the mitigations in HElib, PALISADE, Lattigo and SEAL ([ePrint 2020/1581](https://eprint.iacr.org/2020/1581)).
  - SEAL "only releases the real part of the decoding": **UNVERIFIED**. This comes from a search summary; I could not open the source text.
- **Follow-up on the fix:** Li, Micciancio, Schultz and Sorrell (CRYPTO 2022) prove nearly matching upper and lower bounds on how much noise flooding is needed: "one cannot hope to significantly reduce" it ([ePrint 2022/816](https://eprint.iacr.org/2022/816)). Guo et al. (USENIX Security 2024) recover OpenFHE CKKS keys from a **single** decryption output when the flooding noise comes from average-case rather than worst-case noise estimates ([USENIX](https://www.usenix.org/conference/usenixsecurity24/presentation/guo)).

## 2. IND-CPA^D attacks on exact schemes (BFV / BGV / TFHE)

Shared mechanism: real implementations choose parameters so that a decryption fails with a small but non-negligible probability. The attacker pushes ciphertext noise up to the threshold, for example by repeated additions, and watches which decryptions fail. Each failure leaks information about the secret key.

- **Checri, Sirdey, Boudguiga, Bultel (CEA List), CRYPTO 2024**, "On the practical CPA^D security of 'exact' and threshold FHE schemes and libraries", [ePrint 2024/116](https://eprint.iacr.org/2024/116).
  - Key recovery on Regev that generalises to BFV, BGV and TFHE, using a few thousand ciphertexts and up to about a million evaluations/decryptions, in less than an hour on a laptop.
  - Implemented against SEAL (BFV/BGV), OpenFHE (BFV/BGV), Lattigo (BFV) and TFHElib (TFHE), plus threshold BFV in Lattigo and OpenFHE ([artifact](https://artifacts.iacr.org/crypto/2024/a11/readme.html)).
  - Threshold BFV, BGV and CKKS are insecure without smudging noise after partial decryption.
- **Cheon, Choe, Passelègue, Stehlé, Suvanto (CryptoLab), ACM CCS 2024**, "Attacks Against the IND-CPA^D Security of Exact FHE Schemes", [ePrint 2024/127](https://eprint.iacr.org/2024/127), [ACM DOI](https://dl.acm.org/doi/10.1145/3658644.3690341).
  - Their point: "almost all competitive implementations of exact FHE schemes give away strong correctness", meaning they accept noticeable failure probabilities.
  - Non-adaptive key recovery against all major exact schemes, implemented for BFV in OpenFHE.
  - **Simulated** against the default TFHE-rs CGGI parameter set, because running it was too slow given bootstrapping cost.
  - The exact TFHE-rs version and p_error they used: **UNVERIFIED** (the PDF was blocked).
  - Zellic's summary says the TFHE-rs attack with default parameters "would take more than 300 years", while a weaker non-default set fell in about 4 hours ([Zellic blog, 2024-06](https://www.zellic.io/blog/fhe-security-attacks/)). **UNVERIFIED** against the paper itself.
- **Liu, Wang, Fisch, 2025**, "IND-CPA-D of Relaxed Functional Bootstrapping: A New Attack, A General Fix, and A Stronger Model", [ePrint 2025/1627](https://eprint.iacr.org/2025/1627).
  - Recovers the key in under 10 minutes against all existing *relaxed functional bootstrapping* constructions, **even with negligible failure probability**.
  - Targets those constructions, not TFHE-rs's default bootstrapping.
- **Bernard, Joye, Smart, Walter (Zama), EUROCRYPT 2025**, "Drifting Towards Better Error Probabilities in FHE Schemes", [ePrint 2024/1718](https://eprint.iacr.org/2024/1718). This is Zama's defence, and the source of TFHE-rs's 2^-128.
  - A modulus-switching "drift" technique turns a 2^-64 parameter set into 2^-128 at "no noticeable performance impact".
  - Defines a stronger notion, sIND-CPA^D.
- **Bultel, Checri, Fontaine, Renard, Sirdey, Stan, 2025**, "Achieving CPAD security for BFV: a pragmatic approach", [ePrint 2025/2288](https://eprint.iacr.org/2025/2288). It combines noise-variance monitoring with smudging and automates parameter setting.
- No 2026 paper found in this pass: **UNVERIFIED** that none exists.

## 3. TFHE-rs failure probability

| Version | Default p_error | Stated model | Source |
|---|---|---|---|
| 0.8 | 2^-40 | IND-CPA; custom parameters needed for IND-CPA^D | [docs 0.8](https://docs.zama.org/tfhe-rs/0.8/get-started/security_and_cryptography) |
| pre-1.0 | < 2^-64 | — | [v1.0 blog](https://www.zama.org/post/tfhe-rs-v1-0-stable-cpu-backend) |
| ≥ 1.0 (2025-02-27), incl. 1.8.1 | ≤ 2^-128 | "resilient against attacks in the IND-CPA-D model" | [docs](https://docs.zama.org/tfhe-rs/get-started/security-and-cryptography) |

- The current docs: "In the case where only the IND-CPA model is considered, there is a possibility to choose parameters with a p_error ≤ 2^-64". The x86 CPU 2^-128 sets use the drift mitigation technique ([docs](https://docs.zama.org/tfhe-rs/get-started/security-and-cryptography)).
- So yes, Zama explicitly ties 2^-128 to IND-CPA^D. The v1.0 blog post itself does not use the term.
- The 1.8.1 crate source (`src/high_level_api/keys/inner.rs`) sets the default to `PARAM_MESSAGE_2_CARRY_2_KS_PBS_TUNIFORM_2M128` on CPU and a `..._TUNIFORM_2M128` multi-bit set on GPU. Checked locally.
- In which version the default moved from 2^-40 to 2^-64: **UNVERIFIED**.

## 4. No integrity: malleability by design

- Viand, Knabenhans, Hithnawi, "Verifiable Fully Homomorphic Encryption", [arXiv 2301.07041](https://arxiv.org/abs/2301.07041) (2023).
  - "The same malleability that enables homomorphic computations also raises integrity issues, which have so far been mostly overlooked."
  - Without integrity, a malicious server can run interactive key-recovery attacks.
  - The paper proposes maliciously-secure verifiable FHE as a new notion.
- The standard assumption is an honest-but-curious server; OpenFHE's security notes cover only passive adversaries ([OpenFHE security notes](https://openfhe-development.readthedocs.io/en/latest/sphinx_rsts/intro/security.html)).
- Talk angle: the meter cannot tell whether the utility computed the bill correctly or just returned `Enc(0)`.

## 5. Cost of mitigation

- **Theory:** noise flooding for unbounded IND-CPA^D "requires a superpolynomial modulus" (Li & Micciancio, Sect. 6, [ePrint 2020/1533](https://eprint.iacr.org/2020/1533)). The amount of noise has nearly tight lower bounds, so it cannot be cut much ([ePrint 2022/816](https://eprint.iacr.org/2022/816)).
- **Exact schemes:** "for schemes with negligible failure probability the FHE parameters needed to obtain IND-CPA^D security can be much larger" than for IND-CPA ([Bernard et al., ePrint 2024/1718](https://eprint.iacr.org/2024/1718)). Zama's drift trick avoids most of that cost for TFHE.
- **CKKS in OpenFHE:**
  - `NOISE_FLOODING_DECRYPT` "requires executing all computations twice": a first pass estimates the noise, a second evaluates.
  - It adds noise "like 30 or so bits above the current noise", against about √2× in the default mode. This comes from OpenFHE maintainer ypolyakov ([forum](https://openfhe.discourse.group/t/in-ckks-does-openfhe-always-add-the-noise-before-decoding/1926)).
  - Raising the tolerated number of decryption queries costs precision: 0.5·(log2(M+1)−1) bits ([OpenFHE security notes](https://openfhe-development.readthedocs.io/en/latest/sphinx_rsts/intro/security.html)).
- **Threshold FHE:** needs smudging noise after partial decryption ([ePrint 2024/116](https://eprint.iacr.org/2024/116)).
