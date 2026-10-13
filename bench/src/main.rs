mod fhe;
mod plain;

use plain::N;

use clap::Parser;
use rand::rngs::StdRng;
use rand::{RngExt, SeedableRng};
use std::fmt::Write as _;
use std::hint::black_box;
use std::path::PathBuf;
use std::process::Command;
use std::time::Instant;
use tfhe::prelude::*;

const TFHE_VERSION: &str = "1.8.1";
/// A plain step takes nanoseconds, below what `Instant` resolves: loop it and divide.
const PLAIN_ITERS: u32 = 1_000_000;

/// Smart meter benchmark: plain Rust vs TFHE-rs, step by step.
#[derive(Parser)]
struct Args {
    /// Number of full runs (the median goes on the slides). 1 = quick mode.
    #[arg(long, default_value_t = 5)]
    runs: usize,
    /// Seed for the generated day of readings.
    #[arg(long, default_value_t = 26)]
    seed: u64,
    /// Directory for timings.csv, sizes.csv and meta.json.
    #[arg(long, default_value = "results")]
    out: PathBuf,
}

/// Typical day in Wh per hour: low at night, peaks in the morning and evening.
const PROFILE: [u16; N] = [
    200, 200, 200, 200, 200, 200, 400, 1500, 1500, 600, 400, 400, //
    500, 400, 400, 400, 600, 900, 2500, 2500, 2500, 2500, 800, 300,
];
/// Bounding the readings is what lets `bill` fit in a u32.
const MAX_READING: u16 = 5000;

pub struct Inputs {
    /// Hook: two bytes to compare.
    pub a: u8,
    pub b: u8,
    pub readings: [u16; N],
    pub limit: u16,
    pub tier: u8,
    pub budget: u32,
}

#[derive(Debug, PartialEq)]
pub struct Outputs {
    pub total: u32,
    pub average: u32,
    pub peak_count: u8,
    pub peak_mask: [bool; N],
    pub rate: u16,
    pub bill: u32,
    pub budget_hour: u8,
}

/// The profile with ±20% seeded noise per hour.
fn generate(seed: u64) -> Inputs {
    let mut rng = StdRng::seed_from_u64(seed);
    let mut readings = [0; N];
    for (h, r) in readings.iter_mut().enumerate() {
        *r = (PROFILE[h] as u32 * rng.random_range(80..=120) / 100) as u16;
        assert!(*r <= MAX_READING);
    }
    Inputs {
        a: rng.random(),
        b: rng.random(),
        readings,
        limit: 2000,
        tier: 2,
        budget: 15_000,
    }
}

/// The whole plain scenario, timed as one `day`.
fn run_plain(t: &mut Timings, i: &Inputs) -> Outputs {
    let readings = &i.readings;
    let total = t.plain("total", || plain::total(black_box(readings)));
    let rate = t.plain("tariff_lookup", || plain::tariff_lookup(black_box(i.tier)));
    Outputs {
        total,
        average: t.plain("average", || plain::average(black_box(total))),
        peak_count: t.plain("peak_count", || {
            plain::peak_count(black_box(readings), black_box(i.limit))
        }),
        peak_mask: t.plain("peak_mask", || {
            plain::peak_mask(black_box(readings), black_box(i.limit))
        }),
        rate,
        bill: t.plain("bill", || plain::bill(black_box(total), black_box(rate))),
        budget_hour: t.plain("budget_hour", || {
            plain::budget_hour(black_box(readings), black_box(i.budget))
        }),
    }
}

fn plain_day(i: &Inputs) -> Outputs {
    let total = plain::total(&i.readings);
    let rate = plain::tariff_lookup(i.tier);
    Outputs {
        total,
        average: plain::average(total),
        peak_count: plain::peak_count(&i.readings, i.limit),
        peak_mask: plain::peak_mask(&i.readings, i.limit),
        rate,
        bill: plain::bill(total, rate),
        budget_hour: plain::budget_hour(&i.readings, i.budget),
    }
}

/// Rows of timings.csv: impl, step, run, nanos (fractional for plain steps).
struct Timings {
    run: usize,
    rows: Vec<(&'static str, &'static str, usize, f64)>,
}

impl Timings {
    fn fhe<T>(&mut self, step: &'static str, f: impl FnOnce() -> T) -> T {
        let start = Instant::now();
        let out = f();
        self.rows
            .push(("fhe", step, self.run, start.elapsed().as_nanos() as f64));
        out
    }

    fn plain<T>(&mut self, step: &'static str, f: impl Fn() -> T) -> T {
        let start = Instant::now();
        for _ in 1..PLAIN_ITERS {
            black_box(f());
        }
        let out = black_box(f());
        let nanos = start.elapsed().as_nanos() as f64 / PLAIN_ITERS as f64;
        self.rows.push(("plain", step, self.run, nanos));
        out
    }
}

fn run_fhe(t: &mut Timings, i: &fhe::EncInputs) -> fhe::EncOutputs {
    let total = t.fhe("total", || fhe::total(&i.readings));
    let rate = t.fhe("tariff_lookup", || fhe::tariff_lookup(&i.tier));
    fhe::EncOutputs {
        average: t.fhe("average", || fhe::average(&total)),
        peak_count: t.fhe("peak_count", || fhe::peak_count(&i.readings, &i.limit)),
        peak_mask: t.fhe("peak_mask", || fhe::peak_mask(&i.readings, &i.limit)),
        bill: t.fhe("bill", || fhe::bill(&total, &rate)),
        budget_hour: t.fhe("budget_hour", || fhe::budget_hour(&i.readings, &i.budget)),
        total,
        rate,
    }
}

fn main() -> std::io::Result<()> {
    let args = Args::parse();
    let inputs = generate(args.seed);

    let mut sizes = vec![];
    let mut t = Timings {
        run: 0,
        rows: vec![],
    };
    for run in 0..args.runs {
        t.run = run;
        let expected_gt = t.plain("gt_u8", || {
            plain::gt_u8(black_box(inputs.a), black_box(inputs.b))
        });
        let expected = run_plain(&mut t, &inputs);
        let day = t.plain("day", || plain_day(black_box(&inputs)));
        assert_eq!(day, expected);
        let expected_avg_n = t.plain("average_secret_n", || {
            plain::average_secret_n(black_box(expected.total), black_box(N as u32))
        });
        assert!(
            expected.peak_count > 0 && expected.budget_hour < N as u8,
            "boring day, try another seed: {expected:?}"
        );
        if run == 0 {
            eprintln!("{expected:?}");
        }

        let (ck, sk) = t.fhe("keygen", fhe::keygen);
        if run == 0 {
            sizes = fhe::sizes(&ck, &sk);
        }
        tfhe::set_server_key(sk);
        let enc = t.fhe("encrypt", || fhe::encrypt(&inputs, &ck));
        let enc_gt = t.fhe("gt_u8", || fhe::gt_u8(&enc.a, &enc.b));
        let start = Instant::now();
        let enc_out = run_fhe(&mut t, &enc);
        let nanos = start.elapsed().as_nanos() as f64;
        t.rows.push(("fhe", "day", run, nanos));
        let enc_avg_n = t.fhe("average_secret_n", || {
            fhe::average_secret_n(&enc_out.total, &enc.n)
        });
        let got = t.fhe("decrypt", || fhe::decrypt(&enc_out, &ck));
        if run == 0 {
            sizes.push(("upload", fhe::upload_size(&enc)));
            sizes.push(("download", fhe::download_size(&enc_out)));
        }

        let got_gt: bool = enc_gt.decrypt(&ck);
        assert_eq!(
            got_gt, expected_gt,
            "FHE and plain disagree on gt_u8 (run {run})"
        );
        let got_avg_n: u32 = enc_avg_n.decrypt(&ck);
        assert_eq!(
            got_avg_n, expected_avg_n,
            "FHE and plain disagree on average_secret_n (run {run})"
        );
        assert_eq!(got, expected, "FHE and plain disagree (run {run})");
        eprintln!("run {}/{} ok", run + 1, args.runs);
    }

    std::fs::create_dir_all(&args.out)?;
    let mut csv = String::from("impl,step,run,nanos\n");
    for (imp, step, run, nanos) in &t.rows {
        writeln!(csv, "{imp},{step},{run},{nanos}").unwrap();
    }
    std::fs::write(args.out.join("timings.csv"), csv)?;
    let mut csv = String::from("item,bytes\n");
    for (item, bytes) in &sizes {
        writeln!(csv, "{item},{bytes}").unwrap();
    }
    std::fs::write(args.out.join("sizes.csv"), csv)?;
    std::fs::write(args.out.join("meta.json"), meta(args.runs))?;
    print_medians(&t.rows);
    Ok(())
}

fn meta(runs: usize) -> String {
    let sh = |cmd: &str, arg: &str| {
        Command::new(cmd)
            .args(arg.split(' '))
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
            .unwrap_or_default()
    };
    let cores = std::thread::available_parallelism().map_or(0, |n| n.get());
    // TFHE-rs parallelises with rayon, which RAYON_NUM_THREADS caps
    let threads = std::env::var("RAYON_NUM_THREADS").map_or(cores, |t| t.parse().unwrap());
    format!(
        "{{\n  \"machine\": \"{}\",\n  \"chip\": \"{}\",\n  \"cores\": {cores},\n  \"threads\": {threads},\n  \"tfhe\": \"{TFHE_VERSION}\",\n  \"date\": \"{}\",\n  \"runs\": {runs}\n}}\n",
        sh("sysctl", "-n hw.model"),
        sh("sysctl", "-n machdep.cpu.brand_string"),
        sh("date", "+%F"),
    )
}

fn print_medians(rows: &[(&str, &str, usize, f64)]) {
    let mut keys: Vec<_> = rows.iter().map(|r| (r.0, r.1)).collect();
    keys.sort();
    keys.dedup();
    for (imp, step) in keys {
        let mut v: Vec<f64> = rows
            .iter()
            .filter(|r| (r.0, r.1) == (imp, step))
            .map(|r| r.3)
            .collect();
        v.sort_by(f64::total_cmp);
        println!("{imp:>5} {step:<16} {:>16.2} ns", v[v.len() / 2]);
    }
}
