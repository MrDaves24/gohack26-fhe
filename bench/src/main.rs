mod fhe;
mod plain;

use clap::Parser;
use rand::rngs::StdRng;
use rand::{RngExt, SeedableRng};
use std::fmt::Write as _;
use std::hint::black_box;
use std::path::PathBuf;
use std::process::Command;
use std::time::Instant;

const TFHE_VERSION: &str = "1.8.1";
const SEED: u64 = 26;
/// A plain step takes nanoseconds, below what `Instant` resolves: loop it and divide.
const PLAIN_ITERS: u32 = 1_000_000;

/// Smart meter benchmark: plain Rust vs TFHE-rs, step by step.
#[derive(Parser)]
struct Args {
    /// Number of full runs (the median goes on the slides). 1 = quick mode.
    #[arg(long, default_value_t = 5)]
    runs: usize,
    /// Directory for timings.csv and meta.json.
    #[arg(long, default_value = "results")]
    out: PathBuf,
}

pub struct Inputs {
    pub a: u8,
    pub b: u8,
}

#[derive(Debug, PartialEq)]
pub struct Outputs {
    pub gt: bool,
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

fn main() -> std::io::Result<()> {
    let args = Args::parse();
    let mut rng = StdRng::seed_from_u64(SEED);
    let inputs = Inputs {
        a: rng.random(),
        b: rng.random(),
    };

    let mut t = Timings {
        run: 0,
        rows: vec![],
    };
    for run in 0..args.runs {
        t.run = run;
        let expected = t.plain("gt_u8", || plain::gt_u8(black_box(&inputs)));

        let (ck, sk) = t.fhe("keygen", fhe::keygen);
        tfhe::set_server_key(sk);
        let enc = t.fhe("encrypt", || fhe::encrypt(&inputs, &ck));
        let enc_out = t.fhe("gt_u8", || fhe::gt_u8(&enc));
        let got = t.fhe("decrypt", || fhe::decrypt(&enc_out, &ck));

        assert_eq!(got, expected, "FHE and plain disagree (run {run})");
        eprintln!("run {}/{} ok", run + 1, args.runs);
    }

    std::fs::create_dir_all(&args.out)?;
    let mut csv = String::from("impl,step,run,nanos\n");
    for (imp, step, run, nanos) in &t.rows {
        writeln!(csv, "{imp},{step},{run},{nanos}").unwrap();
    }
    std::fs::write(args.out.join("timings.csv"), csv)?;
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
    format!(
        "{{\n  \"machine\": \"{}\",\n  \"chip\": \"{}\",\n  \"cores\": {cores},\n  \"tfhe\": \"{TFHE_VERSION}\",\n  \"date\": \"{}\",\n  \"runs\": {runs}\n}}\n",
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
        println!("{imp:>5} {step:<10} {:>16.2} ns", v[v.len() / 2]);
    }
}
