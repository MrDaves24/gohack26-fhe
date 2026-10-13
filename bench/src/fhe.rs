//! TFHE-rs implementation: same step names as `plain`, same C-like style.
#![allow(clippy::needless_range_loop)] // index loops read like pseudocode

use crate::plain::{N, TARIFFS};
use crate::{Inputs, Outputs};
use std::mem::size_of;
use tfhe::named::Named;
use tfhe::prelude::*;
use tfhe::safe_serialization::safe_serialized_size;
use tfhe::{
    ClientKey, CompressedServerKey, ConfigBuilder, FheBool, FheUint8, FheUint16, FheUint32,
    ServerKey, Versionize, generate_keys,
};

pub struct EncInputs {
    /// Hook: two bytes to compare.
    pub a: FheUint8,
    pub b: FheUint8,
    pub readings: Vec<FheUint16>,
    pub limit: FheUint16,
    pub tier: FheUint8,
    pub budget: FheUint32,
    /// Division slide: the hour count, as a ciphertext.
    pub n: FheUint32,
}

pub struct EncOutputs {
    pub total: FheUint32,
    pub average: FheUint32,
    pub peak_count: FheUint8,
    pub peak_mask: Vec<FheBool>,
    pub rate: FheUint16,
    pub bill: FheUint32,
    pub budget_hour: FheUint8,
}

pub fn keygen() -> (ClientKey, ServerKey) {
    generate_keys(ConfigBuilder::default())
}

pub fn encrypt(i: &Inputs, ck: &ClientKey) -> EncInputs {
    let mut readings = Vec::new();
    for h in 0..N {
        readings.push(FheUint16::encrypt(i.readings[h], ck));
    }
    EncInputs {
        a: FheUint8::encrypt(i.a, ck),
        b: FheUint8::encrypt(i.b, ck),
        readings,
        limit: FheUint16::encrypt(i.limit, ck),
        tier: FheUint8::encrypt(i.tier, ck),
        budget: FheUint32::encrypt(i.budget, ck),
        n: FheUint32::encrypt(N as u32, ck),
    }
}

/// Hook slide: a single comparison. The result is an FheBool, not a bool: it can't drive an `if`.
pub fn gt_u8(a: &FheUint8, b: &FheUint8) -> FheBool {
    a.gt(b)
}

pub fn total(readings: &[FheUint16]) -> FheUint32 {
    // widen first: a day of u16 readings would wrap silently
    let mut total = FheUint32::encrypt_trivial(0u32);
    for h in 0..N {
        total += FheUint32::cast_from(readings[h].clone());
    }
    total
}

pub fn average(total: &FheUint32) -> FheUint32 {
    // divide by a public value: far cheaper than by a ciphertext
    total / N as u32
}

/// Division slide: the same average, when the count is secret too.
pub fn average_secret_n(total: &FheUint32, n: &FheUint32) -> FheUint32 {
    total / n
}

pub fn peak_count(readings: &[FheUint16], limit: &FheUint16) -> FheUint8 {
    let mut count = FheUint8::encrypt_trivial(0u8);
    for h in 0..N {
        // no branch on a secret: always add, 1 or 0
        let is_peak = readings[h].gt(limit);
        count += FheUint8::select(&is_peak, 1u8, 0u8);
    }
    count
}

pub fn peak_mask(readings: &[FheUint16], limit: &FheUint16) -> Vec<FheBool> {
    // fixed-size output: one flag per hour, never a list of the peak hours
    let mut mask = Vec::new();
    for h in 0..N {
        mask.push(readings[h].gt(limit));
    }
    mask
}

pub fn tariff_lookup(tier: &FheUint8) -> FheUint16 {
    // no secret index: visit every slot, keep only the one that matches
    let mut rate = FheUint16::encrypt_trivial(0u16);
    for i in 0..TARIFFS.len() {
        let is_tier = tier.eq(i as u8);
        rate += FheUint16::select(&is_tier, TARIFFS[i], 0u16);
    }
    rate
}

pub fn bill(total: &FheUint32, rate: &FheUint16) -> FheUint32 {
    // ciphertext × ciphertext: the expensive multiplication
    let rate = FheUint32::cast_from(rate.clone());
    total * &rate / 1000u32
}

pub fn budget_hour(readings: &[FheUint16], budget: &FheUint32) -> FheUint8 {
    // no early exit: the loop length would leak the answer.
    // The running sum only grows, so count the hours still within budget.
    let mut used = FheUint32::encrypt_trivial(0u32);
    let mut hour = FheUint8::encrypt_trivial(0u8);
    for h in 0..N {
        used += FheUint32::cast_from(readings[h].clone());
        hour += FheUint8::select(&used.le(budget), 1u8, 0u8);
    }
    hour
}

pub fn decrypt(o: &EncOutputs, ck: &ClientKey) -> Outputs {
    let mut peak_mask = [false; N];
    for h in 0..N {
        peak_mask[h] = o.peak_mask[h].decrypt(ck);
    }
    Outputs {
        total: o.total.decrypt(ck),
        average: o.average.decrypt(ck),
        peak_count: o.peak_count.decrypt(ck),
        peak_mask,
        rate: o.rate.decrypt(ck),
        bill: o.bill.decrypt(ck),
        budget_hour: o.budget_hour.decrypt(ck),
    }
}

/// Rows of sizes.csv: bytes as `safe_serialize` would send them over the network,
/// next to the plaintext size of each type.
pub fn sizes(ck: &ClientKey, sk: &ServerKey) -> Vec<(&'static str, u64)> {
    vec![
        ("client_key", size(ck)),
        ("server_key", size(sk)),
        ("server_key_compressed", size(&CompressedServerKey::new(ck))),
        ("FheBool", size(&FheBool::encrypt(true, ck))),
        ("FheUint8", size(&FheUint8::encrypt(0u8, ck))),
        ("FheUint16", size(&FheUint16::encrypt(0u16, ck))),
        ("FheUint32", size(&FheUint32::encrypt(0u32, ck))),
        ("bool", size_of::<bool>() as u64),
        ("u8", size_of::<u8>() as u64),
        ("u16", size_of::<u16>() as u64),
        ("u32", size_of::<u32>() as u64),
    ]
}

/// Scenario inputs, client → server (the hook bytes are not part of it).
pub fn upload_size(i: &EncInputs) -> u64 {
    let readings: u64 = i.readings.iter().map(size).sum();
    readings + size(&i.limit) + size(&i.tier) + size(&i.budget)
}

/// Scenario outputs, server → client.
pub fn download_size(o: &EncOutputs) -> u64 {
    let mask: u64 = o.peak_mask.iter().map(size).sum();
    size(&o.total)
        + size(&o.average)
        + size(&o.peak_count)
        + mask
        + size(&o.rate)
        + size(&o.bill)
        + size(&o.budget_hour)
}

fn size<T: serde::Serialize + Versionize + Named>(x: &T) -> u64 {
    safe_serialized_size(x).expect("serialization failed")
}
