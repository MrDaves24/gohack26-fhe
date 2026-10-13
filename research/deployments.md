# Real-world HE deployments (checked 2026-10-13)

## Summary (slide-ready)

- **Apple, iOS 18+: encrypted lookups at scale.** Live Caller ID Lookup, Enhanced Visual Search (Photos), Mail logos, and the iOS 26 Network Extension URL Filter all send an encrypted query that the server answers without reading it. The scheme is BFV, the library is open source ([Apple ML](https://machinelearning.apple.com/research/homomorphic-encryption), [swift-homomorphic-encryption](https://github.com/apple/swift-homomorphic-encryption)).
- **Microsoft Edge Password Monitor (2021):** an encrypted "is this credential in the leak database?" check, built on Microsoft SEAL ([MSR blog](https://www.microsoft.com/en-us/research/blog/password-monitor-safeguarding-passwords-in-microsoft-edge/)).
- **Zama Protocol (Ethereum mainnet, Dec 2025):** confidential token balances and transfers with TFHE. Zama itself states throughput as "over 20 TPS on CPU" ([litepaper](https://docs.zama.org/protocol/zama-protocol-litepaper)).
- **The sources support the thesis.** The big consumer deployments (Apple, Microsoft) are *leveled* HE (BFV, no bootstrapping) evaluating one small fixed circuit: a match, a lookup, a dot product. The one deployment that really is "fully" homomorphic (Zama) computes add/compare on balances, at about 20 TPS on CPU.
- **Nuance worth a sentence:** Jeremy Kun (Google FHE compiler team) labels Apple and Microsoft "SHE" (somewhat HE), not FHE ([fhe-in-production](https://jeremykun.com/fhe-in-production)).

## 1. Apple (iOS 18+)

**Scheme and library.** BFV, "based on the ring learning with errors (RLWE) hardness problem, which is quantum resistant", with "post-quantum 128-bit security" ([Swift blog, 2024-07-30](https://www.swift.org/blog/announcing-swift-homomorphic-encryption/)). The open-source library is `apple/swift-homomorphic-encryption`, which provides PIR and PNNS. The last commit was on 2026-10-12, so it is still active ([repo](https://github.com/apple/swift-homomorphic-encryption)). Its README warns that BFV "does not provide IND-CCA security". Enhanced Visual Search runs on Apple's own BFV implementation in corecrypto, not this library ([Kun](https://jeremykun.com/fhe-in-production)).

**Features and what is computed** ([Apple ML, 2024-10-24](https://machinelearning.apple.com/research/homomorphic-encryption)):
- *Live Caller ID Lookup* (iOS 18): this is PIR, a keyword-to-value lookup. The phone sends the encrypted incoming number, and the server returns the caller ID or block info "without the server knowing the specific phone number in the request" ([Swift blog](https://www.swift.org/blog/announcing-swift-homomorphic-encryption/)). HE is only one of three layers: Oblivious HTTP hides the IP address, Privacy Pass provides anonymous authentication, and PIR hides the number ([Apple docs](https://developer.apple.com/tutorials/data/documentation/identitylookup/understanding-how-live-caller-id-lookup-preserves-privacy.md)).
- *Enhanced Visual Search* (Photos): this is PNNS, private nearest-neighbour search. The client "encrypts a vector embedding" (quantized to 8-bit), and the server "performs HE computation to conduct a nearest neighbor search" over sharded clusters of embeddings, i.e. encrypted dot products. It is combined with differential privacy (ε = 0.8, δ = 10⁻⁶) to hide which shard is queried ([Apple ML](https://machinelearning.apple.com/research/homomorphic-encryption)). Paper: Wally ([arXiv 2406.06761](https://arxiv.org/abs/2406.06761)).
- *Mail logo retrieval* and *parental content filtering* also use PIR ([Apple ML](https://machinelearning.apple.com/research/homomorphic-encryption)).
- *Network Extension URL Filter* (newer): an on-device Bloom filter first, then "off-device database lookups with your PIR server if necessary" ([Apple docs](https://developer.apple.com/tutorials/data/documentation/networkextension/url-filters.md)). The library README lists it next to Live Caller ID. The page doesn't say which OS version introduced it: "iOS 26" is UNVERIFIED (inferred from the doc's date).

**Numbers.** Apple publishes no production latency or size numbers for these features. The library's own tuning example gives orders of magnitude: a keyword PIR over **100,000 rows × 2 bytes** with `n_4096` parameters and one shard gives an **evaluation key of 680.8 KB**, a **query of 28.2 KB**, a **response of 22.6 KB** and **about 51 ms** of server time. With 1,000 rows × 60 KB, the response is 738 KB and the server takes about 610 ms ([ParameterTuning.md](https://github.com/apple/swift-homomorphic-encryption/blob/main/Sources/PrivateInformationRetrieval/PrivateInformationRetrieval.docc/ParameterTuning.md)). A third-party developer measured 51–61 ms on the server and a ~28 KB request in a real Live Caller ID deployment. iOS waits about 1 s, and requests often time out on the network, not on the HE ([dev forum](https://developer.apple.com/forums/thread/848698); a developer report, not Apple).
Talk takeaway: about 50 KB of traffic per query to ask one 2-byte question.

## 2. Microsoft Edge Password Monitor

- **What is computed:** the server evaluates "a matching function on the encrypted credential, obtaining a result (True or False) encrypted under the same client key". The credential is first hashed with a server-secret hash via an OPRF ([MSR blog, 2021-01-21](https://www.microsoft.com/en-us/research/blog/password-monitor-safeguarding-passwords-in-microsoft-edge/)).
- **Library and scheme:** "Microsoft SEAL homomorphic encryption library", modified for low-end devices (same blog). The scheme is FV/BFV (SEAL) per [Kun](https://jeremykun.com/fhe-in-production). The blog doesn't name the scheme, so BFV comes from a secondary source.
- **Scale:** a database of "4 billion credentials" is sharded by a username hash so that "each subset … will contain about 60,000 credentials on average" (MSR blog). Each HE match therefore runs over ~60k entries, not 4 billion.
- **Still current?** The feature is: the Edge policy `PasswordMonitorAllowed` is documented, updated 2026-05-20, for Windows ≥ 85 and macOS ≥ 93 ([MS Learn](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-browser-policies/passwordmonitorallowed)). That it **still uses HE today** is UNVERIFIED. The user-facing page only says "powerful encryption helps protect your information" ([MS Support](https://support.microsoft.com/en-us/topic/protect-your-online-accounts-using-password-monitor-6f660aae-65aa-476c-871a-7fe2bcb0c4c1)), and the only HE source is from 2021.

## 3. Zama (fhEVM / Zama Protocol, TFHE-rs)

- **Live on Ethereum mainnet:** "The Zama Protocol is on mainnet. We just completed the first confidential stablecoin (cUSDT) transfer on Ethereum." (Zama forum, 2025-12-30: [community.zama.org](https://community.zama.org/t/zama-protocol-is-on-mainnet/4124)). The litepaper marks Ethereum "(live)", other EVM chains for H1 2026 and Solana for H2 2026 ([litepaper](https://docs.zama.org/protocol/zama-protocol-litepaper)).
- **What is computed:** encrypted inputs and balances for confidential tokens. Off-chain "coprocessors" run the FHE operations, and decryption goes through a threshold MPC KMS: "13 nodes with a 2/3 majority rule" ([litepaper](https://docs.zama.org/protocol/zama-protocol-litepaper)).
- **Throughput claims** ([litepaper](https://docs.zama.org/protocol/zama-protocol-litepaper)): "over 20 transactions per second on CPU" today, "500-1000 TPS per chain" on GPU by end of 2026 (a target), and "100,000+ tps / chain on a single server" with ASICs (a projection).
- **Scheme:** TFHE with programmable bootstrapping, so it really is *fully* homomorphic. The library is TFHE-rs, the one this talk's benchmark uses.

## 4. Extra: Google Private Join and Compute (additive HE only)

- It computes the "sum of associated values for records that have common identifiers", i.e. intersection-sum, to get the "aggregate conversion rate of advertising campaigns" ([repo](https://github.com/google/private-join-and-compute), [eprint 2019/723](https://eprint.iacr.org/2019/723)). The paper compares instantiations "with different additively homomorphic encryption schemes". Kun reports it as "deployed routinely" ([fhe-in-production](https://jeremykun.com/fhe-in-production)).
- **Not FHE:** additive only, one sum. Useful as "the oldest production HE is a sum".
- Banking and healthcare: I found no primary source for a production FHE deployment. Pilots and press only, so left out (UNVERIFIED).

## Verdict on "real deployments are small targeted lookups"

Supported, with one refinement. Apple (PIR/PNNS) and Microsoft (match against one shard) are lookups or single dot products under leveled BFV. They evaluate one fixed, shallow circuit per query, and every one of them adds sharding, OHTTP, OPRF or differential privacy around the HE to make it practical and private. Zama is the only "general computation" story (smart contracts), but what is deployed is token arithmetic at about 20 TPS on CPU. Suggested slide wording: **"In production: one encrypted question, one shallow circuit, plus a lot of non-HE plumbing."**
