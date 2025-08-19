use unarm::arm;
use unarm::thumb;
use unarm::ParseFlags;
use unarm::ArmVersion;

use std::ffi::CString;
use std::os::raw::c_char;

const ARM9_PARSE_FLAGS: ParseFlags = ParseFlags {
	ual: false,
	version: ArmVersion::V5Te,
};

const ARM7_PARSE_FLAGS: ParseFlags = ParseFlags {
	ual: false,
	version: ArmVersion::V4T,
};

macro_rules! make_new_ins_fn {
	($fn_name:ident, $ins_type:path, $flags:expr) => {
		#[no_mangle]
		pub extern "C" fn $fn_name(ins_code: u32) -> *mut $ins_type {
			let ins = <$ins_type>::new(ins_code, &$flags);
			Box::into_raw(Box::new(ins))
		}
	}
}

macro_rules! make_ins_to_str_fn {
	($fn_name:ident, $ins_type:path, $flags:expr) => {
		#[no_mangle]
		pub extern "C" fn $fn_name(ins: *mut $ins_type) -> *mut c_char {
			unsafe {
				let parsed = (&*ins).parse(&$flags);
				let ins_str = parsed.display(Default::default()).to_string();
				let c_str = CString::new(ins_str).expect("CString::new failed");
				c_str.into_raw()
			}
		}
	};
}

macro_rules! make_get_opcode_id_fn {
	($fn_name:ident, $ins_type:path, $flags:expr) => {
		#[no_mangle]
		pub extern "C" fn $fn_name(ins: *mut $ins_type) -> u16 {
			unsafe {
				(&*ins).op as u16
			}
		}
	};
}

macro_rules! make_ins_is_conditional_fn {
	($fn_name:ident, $ins_type:path, $flags:expr) => {
		#[no_mangle]
		pub extern "C" fn $fn_name(ins: *mut $ins_type) -> bool {
			unsafe {
				(&*ins).is_conditional()
			}
		}
	};
}

make_new_ins_fn!(arm9_new_arm_ins, arm::Ins, ARM9_PARSE_FLAGS);
make_new_ins_fn!(arm7_new_arm_ins, arm::Ins, ARM7_PARSE_FLAGS);
make_new_ins_fn!(arm9_new_thumb_ins, thumb::Ins, ARM9_PARSE_FLAGS);
make_new_ins_fn!(arm7_new_thumb_ins, thumb::Ins, ARM7_PARSE_FLAGS);

make_ins_to_str_fn!(arm9_arm_ins_to_str, arm::Ins, ARM9_PARSE_FLAGS);
make_ins_to_str_fn!(arm7_arm_ins_to_str, arm::Ins, ARM7_PARSE_FLAGS);
make_ins_to_str_fn!(arm9_thumb_ins_to_str, thumb::Ins, ARM9_PARSE_FLAGS);
make_ins_to_str_fn!(arm7_thumb_ins_to_str, thumb::Ins, ARM7_PARSE_FLAGS);

make_get_opcode_id_fn!(arm9_arm_get_opcode_id, arm::Ins, ARM9_PARSE_FLAGS);
make_get_opcode_id_fn!(arm7_arm_get_opcode_id, arm::Ins, ARM7_PARSE_FLAGS);
make_get_opcode_id_fn!(arm9_thumb_get_opcode_id, thumb::Ins, ARM9_PARSE_FLAGS);
make_get_opcode_id_fn!(arm7_thumb_get_opcode_id, thumb::Ins, ARM7_PARSE_FLAGS);

make_ins_is_conditional_fn!(arm9_arm_ins_is_conditional, arm::Ins, ARM9_PARSE_FLAGS);
make_ins_is_conditional_fn!(arm7_arm_ins_is_conditional, arm::Ins, ARM7_PARSE_FLAGS);
make_ins_is_conditional_fn!(arm9_thumb_ins_is_conditional, thumb::Ins, ARM9_PARSE_FLAGS);
make_ins_is_conditional_fn!(arm7_thumb_ins_is_conditional, thumb::Ins, ARM7_PARSE_FLAGS);


#[no_mangle]
pub extern "C" fn free_arm_ins(ptr: *mut arm::Ins) {
	unsafe {
		if !ptr.is_null() {
			drop(Box::from_raw(ptr));
		}
	}
}

#[no_mangle]
pub extern "C" fn free_thumb_ins(ptr: *mut thumb::Ins) {
	unsafe {
		if !ptr.is_null() {
			drop(Box::from_raw(ptr));
		}
	}
}

#[no_mangle]
pub extern "C" fn free_c_str(ptr: *mut c_char) {
	unsafe {
		if !ptr.is_null() {
			drop(CString::from_raw(ptr));
		}
	}
}
