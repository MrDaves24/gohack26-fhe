//! TFHE-rs implementation: same step names as `plain`.

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
    a: FheUint8,
    b: FheUint8,
}

pub struct EncOutputs {
    gt: FheBool,
}

pub fn keygen() -> (ClientKey, ServerKey) {
    generate_keys(ConfigBuilder::default())
}

pub fn encrypt(i: &Inputs, ck: &ClientKey) -> EncInputs {
    EncInputs {
        a: FheUint8::encrypt(i.a, ck),
        b: FheUint8::encrypt(i.b, ck),
    }
}

// the comparison result is an FheBool, not a bool: it can't drive an `if`
pub fn gt_u8(i: &EncInputs) -> EncOutputs {
    EncOutputs { gt: i.a.gt(&i.b) }
}

pub fn decrypt(o: &EncOutputs, ck: &ClientKey) -> Outputs {
    Outputs {
        gt: o.gt.decrypt(ck),
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

fn size<T: serde::Serialize + Versionize + Named>(x: &T) -> u64 {
    safe_serialized_size(x).expect("serialization failed")
}
