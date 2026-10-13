//! TFHE-rs implementation: same step names as `plain`.

use crate::{Inputs, Outputs};
use tfhe::prelude::*;
use tfhe::{ClientKey, ConfigBuilder, FheBool, FheUint8, ServerKey, generate_keys};

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
