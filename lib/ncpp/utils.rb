require_relative '../nitro/nitro.rb'
require_relative '../unarm/unarm.rb'

require 'did_you_mean/jaro_winkler'
require 'did_you_mean/levenshtein'

module NCPP
  module Utils

    DTYPES = [
      { size: 8, signed: false, str: 'unsigned long long int' },
      { size: 4, signed: false, str: 'unsigned long' },
      { size: 2, signed: false, str: 'unsigned short int' },
      { size: 1, signed: false, str: 'unsigned char' },
      { size: 8, signed: true,  str: 'signed long long int' },
      { size: 4, signed: true,  str: 'signed long' },
      { size: 2, signed: true,  str: 'signed short int' },
      { size: 1, signed: true,  str: 'signed char' }
    ].freeze

    DTYPE_IDS = {
      u64:  0, u32: 1, u16: 2, u8: 3,
      s64:  4, s32: 5, s16: 6, s8: 7
    }.freeze

    def self.valid_identifier?(name)
      name.start_with?(/[A-Za-z_]/)
    end

    def self.valid_identifier_check(name) # checks if given name is a valid command/variable identifier
      raise "Invalid identifier '#{name}'" unless valid_identifier?(name)
    end

    def self.check_response(obj, meth)
      raise "#{obj.class} does not respond to #{meth}" unless obj.respond_to? meth
    end

    def self.array_check(arr, meth_name = __callee__)
      raise "#{meth_name} expects an Array" unless arr.is_a? Array
    end

    def self.string_check(arr, meth_name = __callee__)
      raise "#{meth_name} expects a String" unless arr.is_a? String
    end

    def self.block_check(block, meth_name = __callee__)
      raise "#{meth_name} expects a Block" unless block.is_a? Block
    end

    def self.numeric_check(num, meth_name = __callee__)
      raise "#{meth_name} expects a Numeric" unless num.is_a? Numeric
    end

    def self.integer_check(int, meth_name = __callee__)
      raise "#{meth_name} expects an Integer" unless int.is_a? Integer
    end

    def self.print_warning(msg)
      puts 'WARNING'.underline_yellow + ": #{msg}".yellow
    end

    def self.print_info(msg)
      puts 'INFO'.underline_blue + ": #{msg}".blue
    end

    def self.addr_to_sym(addr, ov = nil)
      loc = ov.nil? ? Unarm.cpu.to_s : "ov#{ov}"
      syms = Unarm.get_raw_syms(loc)
      sym = UnarmBind.get_sym_for_addr(addr, syms.ptr, syms.count)
      raise "No symbol found for address '#{addr.to_hex}'" if sym.to_i == 0
      UnarmBind::CStr.new(sym).to_s
    end

    def self.invalid_sym_error(sym, demangled: false)
      alt = demangled ? Unarm.symbols.demangled_map.suggest_similar_key(sym) : Unarm.sym_map.suggest_similar_key(sym)
      raise "'#{sym}' is not a valid symbol#{"\nDid you mean '#{alt}'?" unless alt.nil?}"
    end

    def self.sym_to_addr(sym)
      if sym.start_with? '_Z'
        addr = Unarm.sym_map[sym]
        if addr.nil?
          invalid_sym_error(sym)
        else
          addr
        end
      else
        # pp Unarm.symbols.ambig_demangled
        overloads = Unarm.symbols.ambig_demangled.filter { it[0] == sym }.map { it[1].to_hex }
        if !overloads.empty?
          print_warning "Demangled symbol name '#{sym}' is ambiguous.\n" \
                        "Overload#{'s' if overloads.length != 1 } found at: #{overloads.join(', ')}"
        end
        mangled = Unarm.symbols.demangled_map[sym]
        invalid_sym_error(sym, demangled: true) if mangled.nil?
        Unarm.sym_map[mangled]
      end
    end

    def self.get_sym_ov(sym)
      if sym.start_with?('_Z')
        invalid_sym_error(sym) unless Unarm.sym_map.keys.include?(sym)
      else
        mangled = Unarm.symbols.demangled_map[sym]
        invalid_sym_error(sym, demangled: true) if mangled.nil?
        sym = mangled
      end
      Integer(Unarm.symbols.locs.find {|k,v| v.include?(sym)}[0][2..], exception: false)
    end

    def self.resolve_loc(addr, ov = nil)
      if addr.is_a? String
        ov = get_sym_ov(addr) if ov.nil?
        addr = sym_to_addr(addr)
      end
      [addr, ov]
    end

    def self.resolve_code_loc(addr, ov)
      addr, ov = resolve_loc(addr, ov)
      [addr, ov, ov.nil? || ov == -1 ? $rom.arm9 : $rom.get_overlay(ov)]
    end

    def self.gen_hook_str(type, addr, ov = nil, arg = nil) # generates an NCPatcher hook
      addr, ov = resolve_loc(addr, ov)
      "ncp_#{type}(#{addr.to_hex}#{",#{ov}" if ov}#{",\"#{arg}\"" if arg})"
    end

    def self.gen_hook_description(type)
        "Generates an NCPatcher '#{type}' hook with an address or symbol and an overlay. Specifying the overlay is " \
        "optional if the address is in arm9 or a symbol is used and the symbols file consistently uses tags like " \
        "these to mark symbol locations: '/* arm9_ovX */' (where X is the overlay number)."
    end

    def self.gen_set_hook_str(type, addr, ov = nil, arg = nil)
      addr, ov = resolve_loc(addr, ov)
      "ncp_#{type}(#{addr.to_hex}#{",#{ov}" if ov}#{",#{arg}" if arg})"
    end

    def self.gen_c_over_guard(loc, ov = nil)
      addr, ov, code_bin = resolve_code_loc(loc, ov)
      "ncp_over(#{addr.to_hex}#{",#{ov}" if ov})\n" \
      "static const unsigned int __over_guard_#{addr.to_hex}#{"_#{ov}" if ov} = #{code_bin.read_word(addr).to_hex};"
    end

    def self.modify_ins_immediate(loc, ov, val, thumb: false)
      addr, ov, code_bin = resolve_code_loc(loc, ov)
      asm = thumb ? disasm_thumb_ins(code_bin.read_hword(addr)) : disasm_arm_ins(code_bin.read_word(addr))
      raise 'No immediate found in instruction' if !asm.include? '#'
      gen_hook_str('repl', addr, ov, asm[..asm.index('#')] + val.to_hex )
    end

    def self.gen_repl_array(loc, ov, dtype, arr, const: true)
      addr, ov = resolve_loc(loc, ov)
      "#{gen_hook_str('over', addr, ov)}\nstatic #{'const' if const} " \
      "#{dtype.is_a?(String) ? dtype : DTYPES[dtype][:str]} __array_#{addr.to_hex}_ov#{ov}[] = #{to_c_array(arr)};"
    end

    def self.gen_repl_type_array(loc, ov_or_arr, dtype_sym, arr = nil)
      if arr.nil?
        gen_repl_array(loc, resolve_loc(loc)[1], DTYPE_IDS[dtype_sym], ov_or_arr)
      else
        gen_repl_array(loc, ov_or_arr, DTYPE_IDS[dtype_sym], arr)
      end
    end

    def self.get_reloc_func(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      code_bin.reloc_function(addr)
    end

    def self.disasm_arm_ins(data)
      raise "cannot disassemble a String" if data.is_a? String
      Unarm::ArmIns.disasm(data).str
    end

    def self.disasm_thumb_ins(data)
      raise "cannot disassemble a String" if data.is_a? String
      Unarm::ThumbIns.disasm(data).str
    end

    def self.disasm_hex_seq(hex_byte_str, thumb: false)
      if thumb
        [hex_byte_str].pack('H*').unpack('S*').map { Utils.disasm_thumb_ins(it) }
      else
        [hex_byte_str].pack('H*').unpack('V*').map { Utils.disasm_arm_ins(it) }
      end
    end

    def self.get_instruction(addr, ov = nil)
      addr, ov, code_bin = resolve_code_loc(addr, ov)
      if addr & 1 != 0
        disasm_thumb_ins(code_bin.read16(addr-1))
      else
        disasm_arm_ins(code_bin.read32(addr))
      end
    end

    def self.get_raw_instruction(addr, ov = nil)
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
      element_size = DTYPES[element_type_id][:size]
      element_signed = DTYPES[element_type_id][:signed]
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

    def self.find_branch_to(branch_dest, start_loc, start_ov=nil, from_func: false, find_all: false)
      start_addr, _ov, code_bin = resolve_code_loc(start_loc, start_ov)
      if branch_dest.is_a? Array
        branch_dests = branch_dest.map {|dest| dest.is_a?(String) ? sym_to_addr(dest) : dest }
      else
        branch_dests = [branch_dest.is_a?(String) ? sym_to_addr(branch_dest) : branch_dest]
      end
      if from_func
        func = code_bin.get_function(start_addr)
        addrs = []
        func[:instructions].each do |ins|
          if branch_dests.include?(ins.branch_dest)
            addrs << ins.addr
            break unless find_all
          end
        end
        if find_all
          return addrs
        else
          return addrs[0] unless addrs.empty?
        end
      else
        code_bin.each_ins(start_addr..) do |ins|
          print_warning "Function end may have been passed in search for branch to " \
                        "#{branch_dests.map(&:to_hex).join(', ')}" if ins.function_end?
          return ins.addr if branch_dests.include?(ins.branch_dest)
        end
      end
      raise "Could not find a branch to #{branch_dests.map(&:to_hex).join(', ')}"
    end

    def self.track_reg(reg, from_addr,ov, to_addr)
      start_addr, _ov, code_bin = resolve_code_loc(from_addr, ov)
      to_addr = sym_to_addr(to_addr) if to_addr.is_a? String
      reg = reg.to_sym
      code_bin.each_ins(from_addr..to_addr) do |ins|
        if ins.mnemonic == 'mov'
          if ins.args[1].kind == :reg && ins.args[1].value.reg == reg
            reg = ins.args[0].value.reg
          elsif ins.args[0].value.reg == reg
            reg = nil
            break
          end
        end
      end
      reg = reg.to_s unless reg.nil?
    end

    def self.find_ins_in_func(ins_pattern_str, func_loc, func_ov = nil, find_all: false)
      start_addr, _ov, code_bin = resolve_code_loc(func_loc, func_ov)
      func = code_bin.get_function(start_addr)
      addrs = []
      func[:instructions].each do |ins|
        if ins.str.match?(ins_pattern_str)
          addrs << ins.addr
          break unless find_all
        end
      end
      if find_all
        return addrs
      else
        return addrs[0] unless addrs.empty?
      end
      raise "Could not find instruction pattern in function at #{func_loc}"
    end

    def self.next_addr(current_loc, ov = nil)
      addr, ov, code_bin = resolve_code_loc(current_loc,ov)
      raise 'Next address is out of range' if addr >= code_bin.end_addr - 4
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
      code_bin.read_ins(addr).args[arg_index].value
    end

    def self.get_ins_branch_dest(loc, ov=nil)
      addr, ov, code_bin = resolve_code_loc(loc,ov)
      code_bin.read_ins(addr).branch_dest
    end

    def self.get_ins_target_addr(loc, ov=nil)
      addr, ov, code_bin = resolve_code_loc(loc,ov)
      code_bin.read_ins(addr).target_addr
    end

    def self.to_c_array(arr)
      array_check(arr, 'to_c_array')
      arr.to_s.gsub!('[','{').gsub!(']','}')
    end

    def self.get_func_literal_pool(loc, ov=nil)
      addr, ov, code_bin = resolve_code_loc(loc,ov)
      func = code_bin.get_function(addr)
      func[:literal_pool].map {|_addr,data| data.str }
    end

    def self.get_func_literal_pool_values(loc, ov=nil)
      addr, ov, code_bin = resolve_code_loc(loc,ov)
      func = code_bin.get_function(addr)
      func[:literal_pool].map {|_addr,data| data.raw }
    end

    def self.get_func_literal_pool_addrs(loc, ov=nil)
      addr, ov, code_bin = resolve_code_loc(loc,ov)
      func = code_bin.get_function(addr)
      func[:literal_pool].map {|addr,_data| addr }
    end

    def self.get_function_size(loc, ov=nil)
      addr, ov, code_bin = resolve_code_loc(loc,ov)
      func = code_bin.get_function(addr)
      if func[:literal_pool].empty?
        last = func[:instructions].last
        last.address + last.size - func[:instructions].first
      else
        last = func[:literal_pool][func[:literal_pool].keys.max]
        last.address + last.size - func[:instructions].first.address
      end

    end

    def self.addr_in_overlay?(addr, ov)
      if ov == -1
        $rom.arm9.bounds.include? addr
      elsif ov == -2
        $rom.arm7.bounds.include? addr
      else
        $rom.get_overlay(ov).bounds.include? addr
      end
    end

    def self.addr_in_arm9?(addr)
      $rom.arm9.bounds.include? addr
    end

    def self.addr_in_arm7?(addr)
      $rom.arm7.bounds.include? addr
    end

    def self.find_hex_bytes(ov, hex_str)
      code_bin = ov == -1 ? $rom.arm9 : (ov == -2 ? $rom.arm7 : $rom.get_overlay(ov))
      code_bin.find_hex(hex_str.strip.delete(' '))
    end

    def self.gen_hex_edit(ov, og_hex_str, new_hex_str)
      addr = find_hex_bytes(ov, og_hex_str)
      gen_repl_array(addr, ov, DTYPE_IDS[:u8], [new_hex_str].pack('H*').unpack('C*'))
    end

    class << self
      alias_method :get_u64,  :get_dword
      alias_method :get_u32,  :get_word
      alias_method :get_u16,  :get_hword
      alias_method :get_u8,   :get_byte
      alias_method :get_s64,  :get_signed_dword
      alias_method :get_s32,  :get_signed_word
      alias_method :get_s16,  :get_signed_hword
      alias_method :get_s8,   :get_signed_byte
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

class String
  ANSI_COLORS = {
    black: 30, red: 31, green: 32, yellow: 33,
    blue: 34, purple: 35, cyan: 36, white: 37
  }.freeze

  ANSI_COLORS.each do |color, val|
    define_method(color) do
      "\e[#{val}m#{self}\e[0m"
    end
  end

  ANSI_COLORS.each do |color, val|
    define_method("bold_#{color.to_s}".to_sym) do
      "\e[1;#{val}m#{self}\e[0m"
    end
  end

  ANSI_COLORS.each do |color, val|
    define_method("underline_#{color.to_s}".to_sym) do
      "\e[4;#{val}m#{self}\e[0m"
    end
  end

  ANSI_COLORS.each do |color, val|
    define_method("bg_#{color.to_s}".to_sym) do
      "\e[#{val+10}m#{self}\e[0m"
    end
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

  def ignore_unk_var_at_arg(*arg_idx)
    define_singleton_method(:ignore_unk_var_args) { [*arg_idx] }
    self
  end
  def ignore_unk_var_args
    []
  end

  def impure
    define_singleton_method(:pure?) { false }
    self
  end
  def pure?
    true # NCPP commands that are Procs are marked as pure by default
  end

  def describe(desc)
    define_singleton_method(:description) { desc }
    self
  end
  def description
    nil
  end
end

class Hash
  KEY_SUGGEST_THRESH = 0.7 # if more than 70% certain, suggest key

  KEY_SUGGEST_JARO_WEIGHT        = 0.7 # 70% Jaro-Winkler
  KEY_SUGGEST_LEVENSHTEIN_WEIGHT = 0.3 # 30% Levenshtein

  def suggest_similar_key(key_name)
    key_name = key_name.to_s.downcase
    scores = self.map do |k, _|
      jw = DidYouMean::JaroWinkler.distance(key_name, k.to_s)
      lev = 1.0 - [DidYouMean::Levenshtein.distance(key_name, k.to_s) / [key_name.length].max.to_f, 1.0].min
      jw * KEY_SUGGEST_JARO_WEIGHT + lev * KEY_SUGGEST_LEVENSHTEIN_WEIGHT
    end
    max_score = scores.max
    if max_score < KEY_SUGGEST_THRESH
      nil
    else
      self.keys[scores.index(max_score)].to_s
    end
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

  # TODO: rewrite in Rust?
  def disasm_function(addr)
    is_thumb = addr & 1 != 0
    addr -= 1 if is_thumb

    instructions = [] # [Unarm::Ins]
    labels = {}       # key: addr, val: [xrefs]
    pool = {}         # key: addr, val: Unarm::Data

    send(:"each_#{is_thumb ? 'thumb' : 'arm'}_ins", addr..) do |ins|
      next if pool.keys.include? ins.addr
      raise "Illegal instruction found at #{ins.addr.to_hex}; this is likely not a function." if ins.illegal?

      instructions << ins

      if target = ins.target_addr
        pool[target] ||= Unarm::Data.new(read_word(target), addr: target, loc: get_loc)
      end

      if ins.opcode == :b && (label_addr = ins.branch_dest)
        labels[label_addr] = [] if labels[label_addr].nil?
        labels[label_addr] << ins.addr # add xref

        break if ins.unconditional? && ins.addr > labels.keys.max

      elsif ins.function_end? && (labels.empty? || ins.addr > labels.keys.max)
        break
      end

      if instructions.length > 2500 # TODO: is this a good threshold?
        raise "Function at #{addr.to_hex} is growing exceptionally large; it is likely not a function."
      end
    end

    if !instance_variable_defined? :@functions
      instance_variable_set(:@functions, {})
    end

    @functions[addr] = {
      thumb?: is_thumb,
      instructions: instructions,
      labels: labels,
      literal_pool: pool,
    }
  end
  alias_method :disasm_func, :disasm_function

  # TODO: rewrite in Rust?
  def get_function(addr)
    func = @functions.nil? ? nil : @functions[addr]
    if func.nil?
      disasm_func(addr)
      func = @functions[addr]
    end
    func
  end

  def reloc_function(addr)
    if !instance_variable_defined? :@functions
      instance_variable_set(:@functions, {})
    end

    func = get_function(addr)

    out = ""
    labels = func[:labels].keys
    func[:instructions].each do |ins|
      if label = labels.index(ins.addr)
        out << "#{label+1}:\n"
      end

      if target = ins.target_addr
        out << "#{ins.str[..ins.str.index(',')]} =#{(func[:literal_pool][target]).value}"

      elsif ins.opcode == :b && (label = labels.index(ins.branch_dest))
        out << ins.str[..ins.str.index('#')-1] << "#{label+1}f"

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

  def find_hex(hex_str)
    target_bytes = [hex_str].pack('H*').unpack('C*')
    target_len = target_bytes.length
    found = 0
    found_addr = nil

    each_byte do |byte, addr|
      if byte == target_bytes[found]
        found += 1
        found_addr = addr
        break if found == target_len
      else
        found = 0
      end
    end

    raise 'Could not find hex byte string in binary.' if found != target_len

    found_addr - (target_len - 1) * 4
  end

end
