use unarm::arm;
use unarm::thumb;
use unarm::ParseFlags;
use unarm::ArmVersion;
use unarm::Parser;
use unarm::ParseMode;
use unarm::Endian;

use std::ffi::CString;
use std::os::raw::c_char;
use std::slice;

const ARM9_PARSE_FLAGS: ParseFlags = ParseFlags {
	ual: false,
	version: ArmVersion::V5Te,
};

const ARM7_PARSE_FLAGS: ParseFlags = ParseFlags {
	ual: false,
	version: ArmVersion::V4T,
};

pub fn parse_mode_from_u32(v: u32) -> Option<ParseMode> {
    match v {
        0 => Some(ParseMode::Arm),
        1 => Some(ParseMode::Thumb),
        2 => Some(ParseMode::Data),
        _ => None,
    }
}

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
		pub extern "C" fn $fn_name(ins: *const $ins_type) -> u16 {
			unsafe {
				(&*ins).op as u16
			}
		}
	};
}

macro_rules! make_ins_is_conditional_fn {
	($fn_name:ident, $ins_type:path) => {
		#[no_mangle]
		pub extern "C" fn $fn_name(ins: *const $ins_type) -> bool {
			unsafe {
				(&*ins).is_conditional()
			}
		}
	};
}

macro_rules! make_ins_updates_condition_flags_fn {
	($fn_name:ident, $ins_type:path) => {
		#[no_mangle]
		pub extern "C" fn $fn_name(ins: *mut $ins_type) -> bool {
			unsafe {
				(&*ins).updates_condition_flags()
			}
		}
	};
}

macro_rules! make_free_ins_fn {
	($fn_name:ident, $ins_type:path) => {
		#[no_mangle]
		pub extern "C" fn $fn_name(ins: *mut $ins_type) {
			unsafe {
				if !ins.is_null() {
					drop(Box::from_raw(ins));
				}
			}
		}
	};
}

macro_rules! make_new_parser_fn {
	($fn_name:ident, $flags:expr) => {
		#[no_mangle]
		pub extern "C" fn $fn_name(mode: u32, addr: u32, data: *const u8, data_size: u32) -> *mut Parser<'static> {
			assert!(!data.is_null());
			let slice = unsafe { slice::from_raw_parts(data, data_size as usize) };
			let parser = Parser::new(parse_mode_from_u32(mode).unwrap(), addr, Endian::Little, $flags, slice);
			Box::into_raw(Box::new(parser))
		}
	}
}

macro_rules! make_free_parser_fn {
	($fn_name:ident) => {
		#[no_mangle]
		pub extern "C" fn $fn_name(parser: *mut Parser<'static>) {
			unsafe {
				if !parser.is_null() {
					drop(Box::from_raw(parser));
				}
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

make_ins_is_conditional_fn!(arm_ins_is_conditional, arm::Ins);
make_ins_is_conditional_fn!(thumb_ins_is_conditional, thumb::Ins);

make_ins_updates_condition_flags_fn!(arm_ins_updates_condition_flags, arm::Ins);
make_ins_updates_condition_flags_fn!(thumb_ins_updates_condition_flags, thumb::Ins);

make_free_ins_fn!(free_arm_ins, arm::Ins);
make_free_ins_fn!(free_thumb_ins, thumb::Ins);

make_new_parser_fn!(arm9_new_parser, ARM9_PARSE_FLAGS);
make_new_parser_fn!(arm7_new_parser, ARM7_PARSE_FLAGS);
make_free_parser_fn!(arm9_free_parser, ARM9_PARSE_FLAGS);
make_free_parser_fn!(arm7_free_parser, ARM7_PARSE_FLAGS);

#[no_mangle]
pub extern "C" fn free_c_str(ptr: *mut c_char) {
	unsafe {
		if !ptr.is_null() {
			drop(CString::from_raw(ptr));
		}
	}
}
