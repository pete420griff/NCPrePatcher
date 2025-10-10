require_relative '../nitro/nitro.rb'
require_relative '../unarm/unarm.rb'

module NCPP
  module Utils

    DATA_TYPES = [
      { size: 8, signed: false },
      { size: 4, signed: false },
      { size: 2, signed: false },
      { size: 1, signed: false },
      { size: 8, signed: true  },
      { size: 4, signed: true  },
      { size: 2, signed: true  },
      { size: 1, signed: true  }
    ].freeze

    def self.valid_identifier_check(name) # checks if given name is a valid command/variable identifier
      raise "Invalid identifier: #{name}" unless name.start_with?(/[A-Za-z_]/)
    end

    def self.addr_to_sym(addr, ov = nil)
      loc = ov.nil? ? Unarm.cpu.to_s : "ov#{ov}"
      syms = Unarm.get_raw_syms(loc)
      UnarmBind::CStr.new(UnarmBind.get_sym_for_addr(addr, syms.ptr, syms.count)).to_s
    end

    def self.sym_to_addr(sym)
      if sym.start_with? '_Z'
        Unarm.sym_map[sym]
      else
        demangled = Unarm.symbols.demangled_map[sym]
        raise "#{sym} is not a valid symbol" if demangled.nil?
        Unarm.sym_map[demangled]
      end
    end

    def self.get_sym_ov(sym)
      sym = Unarm.symbols.demangled_map[sym] unless sym.start_with?('_Z')
      Integer(Unarm.symbols.locs.find {|k,v| v.include? sym}[0][2..], exception: false)
    end

    def self.resolve_loc(addr, ov)
      if addr.is_a? String
        addr = Unarm.symbols.demangled_map[addr] unless addr.start_with?('_Z')
        raise "Not a valid symbol" if addr.nil?
        ov = get_sym_ov(addr) if ov != -1 && ov.nil?
        addr = sym_to_addr(addr)
      end
      [addr, ov]
    end

    def self.resolve_code_loc(addr, ov)
      addr, ov = resolve_loc(addr, ov)
      [addr, ov, ov.nil? || ov == -1 ? $rom.arm9 : $rom.get_overlay(ov)]
    end

    def self.gen_hook_str(type, addr, ov=nil, asm=nil) # generates an NCPatcher hook
      addr, ov = resolve_loc(addr, ov)
      "ncp_#{type}(#{addr.to_hex}#{",#{ov}" if ov}#{",\"#{asm}\"" if asm})"
    end

    def self.reloc_func(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      code_bin.reloc_func(addr)
    end

    def self.get_instruction(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      if addr & 1 != 0
        code_bin.read_thumb_instruction(addr-1)
      else
        code_bin.read_arm_instruction(addr)
      end
    end
    def self.get_dword(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      code_bin.read_dword(addr).unsigned(64)
    end

    def self.get_word(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      code_bin.read_word(addr).unsigned(32)
    end

    def self.get_hword(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      code_bin.read_hword(addr).unsigned(16)
    end

    def self.get_byte(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      code_bin.read_byte(addr).unsigned(8)
    end

    def self.get_signed_dword(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      code_bin.read_dword(addr).signed(64)
    end

    def self.get_signed_word(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      code_bin.read_word(addr).signed(32)
    end

    def self.get_signed_hword(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      code_bin.read_hword(addr).signed(16)
    end

    def self.get_signed_byte(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      code_bin.read_byte(addr).signed(8)
    end

    def self.get_cstring(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      code_bin.read_cstr(addr)
    end

    def self.get_array(addr, ov, element_type_id, element_count)
      element_size = DATA_TYPES[element_type_id][:size]
      element_signed = DATA_TYPES[element_type_id][:signed]
      raise ArgumentError, 'element size must be 1, 2, 4, or 8 (bytes)' unless [1,2,4,8].include?(element_size)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      (0...element_count).map do |i|
        offset = addr + i * element_size
        if element_signed
          code_bin.send(:"read#{element_size * 8}", offset).signed(element_size*8)
        else
          code_bin.send(:"read#{element_size * 8}", offset)
        end
      end
    end

    def self.find_first_branch_to(branch_dest, start_loc, start_ov=nil)
      start_addr, _ov, code_bin = resolve_code_loc(start_loc, start_ov)
      branch_dest = sym_to_addr(branch_dest) if branch_dest.is_a? String
      code_bin.each_ins(start_addr..) { |ins| return ins.addr if ins.branch_dest == branch_dest }
      raise "Could not find a branch to #{branch_dest.to_hex}"
    end

    def self.next_addr(current_loc, ov = nil)
      addr, ov, code_bin = resolve_code_loc(current_loc,ov)
      is_thumb = addr & 1 != 0
      addr -= 1 if is_thumb
      addr += is_thumb ? 2 : 4
    end

    def self.get_ins_mnemonic(loc, ov = nil)
      addr, ov, code_bin = resolve_code_loc(loc,ov)
      code_bin.read_ins(addr).mnemonic
    end

    def self.get_ins_arg(loc, ov, arg_index)
      addr, ov, code_bin = resolve_code_loc(loc,ov)
      code_bin.read_ins(addr).args[arg_index]
    end

    def self.to_c_array(arr)
      arr.to_s.gsub!('[','{').gsub!(']','}')
    end

    class << self
      alias_method :get_u64, :get_dword
      alias_method :get_u32, :get_word
      alias_method :get_u16, :get_hword
      alias_method :get_u8, :get_byte
      alias_method :get_s64, :get_signed_dword
      alias_method :get_s32, :get_signed_word
      alias_method :get_s16, :get_signed_hword
      alias_method :get_s8, :get_signed_byte
      alias_method :get_cstr, :get_cstring
    end
  end
end

#
# Core class extensions
#
class Integer
  def to_hex
    '0x' + self.to_s(16)
  end

  def signed(bits)
    mask = (1 << bits) - 1
    n = self & mask
    sign_bit = 1 << (bits - 1)
    n >= sign_bit ? n - (1 << bits) : n
  end

  def unsigned(bits)
    self & ((1 << bits) - 1)
  end
end

class Proc
  def returns(type)
    define_singleton_method(:return_type) { type }
    self
  end
  def return_type
    nil
  end

  def cacheable
    define_singleton_method(:cacheable?) { true }
    self
  end
  def cacheable?
    false
  end
end

#
# Various utility methods tying Nitro to the Unarm module
#
class Nitro::CodeBin

  attr_reader :functions

  def get_location
    respond_to?(:id) ? "ov#{id}" : Unarm.cpu.to_s
  end
  alias_method :get_loc, :get_location

  def read_arm_instruction(addr)
      Unarm::ArmIns.disasm(read32(addr), addr, get_loc)
  end
  alias_method :read_arm_ins, :read_arm_instruction
  alias_method :read_ins, :read_arm_instruction

  def read_thumb_instruction(addr)
      Unarm::ThumbIns.disasm(read16(addr), addr, get_loc)
  end
  alias_method :read_thumb_ins, :read_thumb_instruction

  def each_arm_instruction(range = bounds)
    each_word(range) do |word, addr|
      yield Unarm::ArmIns.disasm(word, addr, get_loc)
    end
  end
  alias_method :each_arm_ins, :each_arm_instruction
  alias_method :each_ins, :each_arm_instruction

  def each_thumb_instruction(range = bounds)
    each_hword(range) do |hword, addr|
      yield Unarm::ThumbIns.disasm(hword, addr, get_loc)
    end
  end
  alias_method :each_thumb_ins, :each_thumb_instruction

  def disasm_function(addr)
    is_thumb = addr & 1 != 0
    addr -= 1 if is_thumb

    instructions = []
    pool = []

    send(:"each_#{is_thumb ? 'thumb' : 'arm'}_ins", addr..) do |ins|
      raise "Illegal instruction found at #{ins.addr.to_hex}; this is likely not a function." if ins.illegal?
      
      if target = ins.target_addr
        pool << Unarm::Data.new(read_word(target), addr: target, loc: get_loc)
      end

      instructions << ins

      break if ins.function_end?

      if instructions.length > 2500
        raise "Function at #{addr.to_hex} is growing exceptionally large; this is likely not a function."
      end
    end

    if !instance_variable_defined? :@functions
      instance_variable_set(:@functions, {})
    end

    @functions[addr] = {
      thumb?: is_thumb,
      instructions: instructions,
      literal_pool: pool,
    }
  end
  alias_method :disasm_func, :disasm_function

  def reloc_function(addr)
    if !instance_variable_defined? :@functions
      instance_variable_set(:@functions, {})
    end

    func = @functions[addr]
    if func.nil?
      disasm_func(addr)
      func = @functions[addr]
    end

    out = ""
    func[:instructions].each do |ins|
      if target = ins.target_addr
        out << "#{ins.str[..ins.str.index('[')-2]} =#{(func[:literal_pool].find {it.addr == target}).value}"

      elsif (branch = ins.branch_dest) && ins.str.include?('#') &&
            (dest = ins.str[ins.str.index('#')+1..].hex) &&
            dest != branch && (dest += ins.addr) &&
            (dest < func[:instructions][0].addr || dest > func[:instructions][-1].addr)

        out << ins.str[..ins.str.index('#')] << dest.to_hex

      else
        out << ins.str
      end

      out << "\n"
    end

    out
  end
  alias_method :reloc_func, :reloc_function

end
