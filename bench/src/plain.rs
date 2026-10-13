//! Plain implementation: one function per named step.

use crate::{Inputs, Outputs};

pub fn gt_u8(i: &Inputs) -> Outputs {
    Outputs { gt: i.a > i.b }
}
