use unarm::arm;
use unarm::thumb;
use unarm::ParseFlags;
use unarm::ArmVersion;
use unarm::Parser;
use unarm::ParseMode;
use unarm::args::*;

use std::ffi::CString;
use std::os::raw::c_char;
use std::slice;

#[repr(C)]
pub enum ArgumentKind {
    None,
    Reg,
    RegList,
    CoReg,
    StatusReg,
    StatusMask,
    Shift,
    ShiftImm,
    ShiftReg,
    UImm,
    SatImm,
    SImm,
    OffsetImm,
    OffsetReg,
    BranchDest,
    CoOption,
    CoOpcode,
    CoprocNum,
    CpsrMode,
    CpsrFlags,
    Endian,
}

#[repr(C)]
pub union ArgumentValue {
	reg: Reg,
	reg_list: RegList,
	co_reg: CoReg,
	status_reg: StatusReg,
	status_mask: StatusMask,
    shift: Shift,
    shift_imm: ShiftImm,
    shift_reg: ShiftReg,
    u_imm: u32,
    sat_imm: u32,
    s_imm: i32,
    offset_imm: OffsetImm,
    offset_reg: OffsetReg,
    branch_dest: i32,
    co_option: u32,
    co_opcode: u32,
    coproc_num: u32,
    cpsr_mode: CpsrMode,
    cpsr_flags: CpsrFlags,
    endian: Endian,
}

#[repr(C)]
pub struct CArgument {
	kind: ArgumentKind,
	value: ArgumentValue,
}

// this really fucking sucks, surely there's a better way...
impl From<Argument> for CArgument {
    fn from(arg: Argument) -> Self {
        match arg {
            Argument::None => Self { kind: ArgumentKind::None, value: ArgumentValue { reg: Reg::default() }, },
            Argument::Reg(r) => Self { kind: ArgumentKind::Reg, value: ArgumentValue { reg: r }, },
            Argument::RegList(l) => Self { kind: ArgumentKind::RegList, value: ArgumentValue { reg_list: l }, },
            Argument::CoReg(c) => Self { kind: ArgumentKind::CoReg, value: ArgumentValue { co_reg: c }, },
            Argument::StatusReg(s) => Self { kind: ArgumentKind::StatusReg, value: ArgumentValue { status_reg: s }, },
            Argument::StatusMask(m) => Self { kind: ArgumentKind::StatusMask, value: ArgumentValue { status_mask: m }, },
            Argument::Shift(s) => Self { kind: ArgumentKind::Shift, value: ArgumentValue { shift: s }, },
            Argument::ShiftImm(si) => Self { kind: ArgumentKind::ShiftImm, value: ArgumentValue { shift_imm: si }, },
            Argument::ShiftReg(sr) => Self { kind: ArgumentKind::ShiftReg, value: ArgumentValue { shift_reg: sr }, },
            Argument::UImm(u) => Self { kind: ArgumentKind::UImm, value: ArgumentValue { u_imm: u }, },
            Argument::SatImm(si) => Self { kind: ArgumentKind::SatImm, value: ArgumentValue { sat_imm: si }, },
            Argument::SImm(si) => Self { kind: ArgumentKind::SImm, value: ArgumentValue { s_imm: si }, },
            Argument::OffsetImm(oi) => Self { kind: ArgumentKind::OffsetImm, value: ArgumentValue { offset_imm: oi }, },
            Argument::OffsetReg(or) => Self { kind: ArgumentKind::OffsetReg, value: ArgumentValue { offset_reg: or }, },
            Argument::BranchDest(bd) => Self { kind: ArgumentKind::BranchDest, value: ArgumentValue { branch_dest: bd }, },
            Argument::CoOption(co) => Self { kind: ArgumentKind::CoOption, value: ArgumentValue { co_option: co }, },
            Argument::CoOpcode(co) => Self { kind: ArgumentKind::CoOpcode, value: ArgumentValue { co_opcode: co }, },
            Argument::CoprocNum(cn) => Self { kind: ArgumentKind::CoprocNum, value: ArgumentValue { coproc_num: cn }, },
            Argument::CpsrMode(cm) => Self { kind: ArgumentKind::CpsrMode, value: ArgumentValue { cpsr_mode: cm }, },
            Argument::CpsrFlags(cf) => Self { kind: ArgumentKind::CpsrFlags, value: ArgumentValue { cpsr_flags: cf }, },
            Argument::Endian(e) => Self { kind: ArgumentKind::Endian, value: ArgumentValue { endian: e }, },
        }
    }
}

#[repr(C)]
pub struct Symbol {
	name: *const c_char,
	addr: u32,
}

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

macro_rules! make_ins_to_str_with_syms_fn {
	($fn_name:ident, $ins_type:path, $flags:expr) => {
		#[no_mangle]
		pub extern "C" fn $fn_name(ins: *mut $ins_type, symbols: *const Symbol, symbol_count: u32) -> *mut c_char {
			unsafe {
				let parsed = (&*ins).parse(&$flags);
				// TODO: CONVERT SYMBOLS!!
				let ins_str = parsed.display_with_symbols(Default::default(), symbols).to_string();
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
			let parser = Parser::new(parse_mode_from_u32(mode).unwrap(), addr, unarm::Endian::Little, $flags, slice);
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
make_free_parser_fn!(arm9_free_parser);
make_free_parser_fn!(arm7_free_parser);

#[no_mangle]
pub extern "C" fn free_c_str(ptr: *mut c_char) {
	unsafe {
		if !ptr.is_null() {
			drop(CString::from_raw(ptr));
		}
	}
}
