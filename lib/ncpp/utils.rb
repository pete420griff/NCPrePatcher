require_relative '../nitro/nitro.rb'
require_relative '../unarm/unarm.rb'

module NCPP
  module Utils
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
        sym_to_addr(Unarm.symbols.demangled_map[sym])
      end
    end

    def self.get_sym_ov(sym)
      Integer(Unarm.symbols.locs.find {|k,v| v.include? sym}[0][2..], exception: false)
    end

    def self.resolve_loc(addr, ov)
      if addr.is_a? String
        addr = Unarm.symbols.demangled_map[addr] unless addr.start_with?('_Z')
        ov = get_sym_ov(addr) if ov.nil?
        addr = sym_to_addr(addr)
      end
      [addr, ov]
    end

    def self.resolve_code_loc(addr, ov)
      addr, ov = resolve_loc(addr, ov)
      [addr, ov, ov.nil? ? $rom.arm9 : $rom.get_overlay(ov)]
    end

    def self.gen_hook_str(type, addr, ov=nil, asm=nil) # generates an NCPatcher hook
      addr, ov = resolve_loc(addr, ov)
      "ncp_#{type}(#{addr.to_hex}#{",#{ov}" if ov}#{",\"#{asm}\"" if asm})"
    end

    def self.reloc_func(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      code_bin.reloc_func(addr)
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

    def self.get_signed_byte(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      code_bin.read_byte(addr).signed(8)
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

    def self.get_byte(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      code_bin.read_byte(addr).unsigned(8)
    end

    def self.get_signed_byte(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      code_bin.read_byte(addr).signed(8)
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
    n
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
      raise "Illegal instruction found at #{ins.addr}; this is likely not a function." if ins.illegal?
      
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
