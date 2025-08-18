extern crate unarm;
// use unarm::{args::*, v5te::arm::{Ins, Opcode}};

use unarm::arm::Ins;
use unarm::ParseFlags;
use unarm::ArmVersion;

use std::ffi::CString;
use std::os::raw::c_char;


#[no_mangle]
pub extern "C" fn disasm_arm_ins(ins_code: u32) -> *mut c_char {
	let parse_flags = ParseFlags { ual: false, version: ArmVersion::V5Te };
	let parsed = Ins::new(ins_code, &parse_flags).parse(&parse_flags);
	let ins_str = parsed.display(Default::default()).to_string();
	let c_str = CString::new(ins_str).expect("CString::new failed");
	c_str.into_raw()
}

#[no_mangle]
pub extern "C" fn free_c_str(ptr: *mut c_char) {
	unsafe {
		if !ptr.is_null() {
			let _ = CString::from_raw(ptr);
		}
	}
}
