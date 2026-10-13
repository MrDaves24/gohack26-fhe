//! Plain implementation: one function per named step.
//! Written like C on purpose: the slides are for people who don't read Rust.
#![allow(clippy::needless_range_loop)] // index loops read like pseudocode

pub const N: usize = 24;
/// Price per kWh in centimes, by tariff tier. Public: the server knows it.
pub const TARIFFS: [u16; 4] = [20, 25, 30, 40];

/// Hook slide: a single comparison.
pub fn gt_u8(a: u8, b: u8) -> bool {
    a > b
}

pub fn total(readings: &[u16; N]) -> u32 {
    let mut total: u32 = 0;
    for h in 0..N {
        total += readings[h] as u32;
    }
    total
}

pub fn average(total: u32) -> u32 {
    total / N as u32
}

/// Comparison for the division slide: the same average, divided by a secret count.
pub fn average_secret_n(total: u32, n: u32) -> u32 {
    total / n
}

pub fn peak_count(readings: &[u16; N], limit: u16) -> u8 {
    let mut count: u8 = 0;
    for h in 0..N {
        if readings[h] > limit {
            count += 1;
        }
    }
    count
}

pub fn peak_mask(readings: &[u16; N], limit: u16) -> [bool; N] {
    let mut mask = [false; N];
    for h in 0..N {
        mask[h] = readings[h] > limit;
    }
    mask
}

pub fn tariff_lookup(tier: u8) -> u16 {
    TARIFFS[tier as usize]
}

/// Wh × centimes/kWh / 1000 = centimes.
pub fn bill(total: u32, rate: u16) -> u32 {
    total * rate as u32 / 1000
}

/// First hour where the energy used so far exceeds the budget, N if never.
pub fn budget_hour(readings: &[u16; N], budget: u32) -> u8 {
    let mut used: u32 = 0;
    for h in 0..N {
        used += readings[h] as u32;
        if used > budget {
            return h as u8;
        }
    }
    N as u8
}
