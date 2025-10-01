require 'ffi'

module UnarmBind
  extend FFI::Library
  ffi_lib [
    File.expand_path("unarm", __dir__),
    File.expand_path("unarm.dylib", __dir__),
    File.expand_path("unarm.so", __dir__),
  ]

  typedef :pointer, :ins_handle
  typedef :pointer, :cstr_handle
  typedef :pointer, :parser_handle
  typedef :pointer, :symbols_handle
  typedef :pointer, :ins_args_handle

  attach_function :arm9_new_arm_ins, [:uint32], :ins_handle
  attach_function :arm9_new_thumb_ins, [:uint32], :ins_handle
  attach_function :arm7_new_arm_ins, [:uint32], :ins_handle
  attach_function :arm7_new_thumb_ins, [:uint32], :ins_handle

  attach_function :arm9_new_parser, [:uint32], :parser_handle
  attach_function :arm7_new_parser, [:uint32], :parser_handle
  
  attach_function :arm9_arm_ins_to_str, [:ins_handle], :cstr_handle
  attach_function :arm7_arm_ins_to_str, [:ins_handle], :cstr_handle
  attach_function :arm9_thumb_ins_to_str, [:ins_handle], :cstr_handle
  attach_function :arm7_thumb_ins_to_str, [:ins_handle], :cstr_handle

  attach_function :arm9_arm_ins_to_str_with_syms,
    [:ins_handle, :symbols_handle, :uint32, :uint32, :int32], :cstr_handle
  attach_function :arm7_arm_ins_to_str_with_syms,
    [:ins_handle, :symbols_handle, :uint32, :uint32, :int32], :cstr_handle
  attach_function :arm9_thumb_ins_to_str_with_syms,
    [:ins_handle, :symbols_handle, :uint32, :uint32, :int32], :cstr_handle
  attach_function :arm7_thumb_ins_to_str_with_syms,
    [:ins_handle, :symbols_handle, :uint32, :uint32, :int32], :cstr_handle

  attach_function :arm9_arm_ins_get_args, [:ins_handle], :ins_args_handle
  attach_function :arm7_arm_ins_get_args, [:ins_handle], :ins_args_handle
  attach_function :arm9_thumb_ins_get_args, [:ins_handle], :ins_args_handle
  attach_function :arm7_thumb_ins_get_args, [:ins_handle], :ins_args_handle

  attach_function :arm9_arm_ins_get_opcode_id, [:ins_handle], :uint16
  attach_function :arm7_arm_ins_get_opcode_id, [:ins_handle], :uint16
  attach_function :arm9_thumb_ins_get_opcode_id, [:ins_handle], :uint16
  attach_function :arm7_thumb_ins_get_opcode_id, [:ins_handle], :uint16

  attach_function :arm_ins_is_conditional, [:ins_handle], :bool
  attach_function :thumb_ins_is_conditional, [:ins_handle], :bool

  attach_function :arm_ins_updates_condition_flags, [:ins_handle], :bool
  attach_function :thumb_ins_updates_condition_flags, [:ins_handle], :bool

  attach_function :arm_ins_is_data_operation, [:ins_handle], :bool
  attach_function :thumb_ins_is_data_operation, [:ins_handle], :bool

  attach_function :get_sym_for_addr, [:uint32, :symbols_handle, :uint32], :cstr_handle

  attach_function :free_arm_ins, [:ins_handle], :void
  attach_function :free_thumb_ins, [:ins_handle], :void
  attach_function :free_ins_args, [:ins_args_handle, :uint32], :void
  attach_function :arm9_free_parser, [:parser_handle], :void
  attach_function :arm7_free_parser, [:parser_handle], :void
  attach_function :free_c_str, [:cstr_handle], :void

  # NOTE: some of the following instructions are not valid in ARMv5TE/v4T
  OPCODE = [
    :illegal, :adc, :add, :and, :asr, :b, :bl, :bic, :bkpt, :blxi,
    :blxr, :bx, :bxj, :cdp, :cdp2, :clrex, :clz, :cmn, :cmp, :cps,
    :csdb, :dbg, :eor, :ldc, :ldc2, :ldmw, :ldm, :ldmp, :ldmpw, :ldmpcw,
    :ldmpc, :ldr, :ldrb, :ldrbt, :ldrd, :ldrex, :ldrexb, :ldrexd, :ldrexh, :ldrh,
    :ldrsb, :ldrsh, :ldrt, :lsl, :lsr, :mcr, :mcr2, :mcrr, :mcrr2, :mla,
    :mov, :movimm, :movreg, :mrc, :mrc2, :mrrc, :mrrc2, :mrs, :msri, :msr,
    :mul, :mvn, :nop, :orr, :pkhbt, :pkhtb, :pld, :popm, :popr, :pushm,
    :pushr, :qadd, :qadd16, :qadd8, :qasx, :qdadd, :qdsub, :qsax, :qsub, :qsub16,
    :qsub8, :rev, :rev16, :revsh, :rfe, :ror, :rrx, :rsb, :rsc, :sadd16,
    :sadd8, :sasx, :sbc, :sel, :setend, :sev, :shadd16, :shadd8, :shasx, :shsax,
    :shsub16, :shsub8, :smla, :smlad, :smlal, :smlalxy, :smlald, :smlaw, :smlsd, :smlsld,
    :smmla, :smmls, :smmul, :smuad, :smul, :smull, :smulw, :smusd, :srs, :ssat,
    :ssat16, :ssax, :ssub16, :ssub8, :stc, :stc2, :stm, :stmw, :stmp, :stmpw,
    :str, :strb, :strbt, :strd, :strex, :strexb, :strexd, :strexh, :strh, :strt,
    :sub, :svc, :swi, :swp, :swpb, :sxtab, :sxtab16, :sxtah, :sxtb, :sxtb16,
    :sxth, :teq, :tst, :uadd16, :uadd8, :uasx, :udf, :uhadd16, :uhadd8, :uhasx,
    :uhsax, :uhsub16, :uhsub8, :umaal, :umlal, :umull, :uqadd16, :uqadd8, :uqasx, :uqsax,
    :uqsub16, :uqsub8, :usad8, :usada8, :usat, :usat16, :usax, :usub16, :usub8, :uxtab,
    :uxtab16, :uxtah, :uxtb, :uxtb16, :uxth, :wfe, :wfi, :yield
  ].freeze

  OPCODE_MNEMONIC = [
    '<illegal>', 'adc', 'add', 'and', 'asr', 'b', 'bl', 'bic', 'bkpt', 'blx',
    'blx', 'bx', 'bxj', 'cdp', 'cdp2', 'clrex', 'clz', 'cmn', 'cmp', 'cps',
    'csdb', 'dbg', 'eor', 'ldc', 'ldc2', 'ldm', 'ldm', 'ldm', 'ldm', 'ldm',
    'ldm', 'ldr', 'ldrb', 'ldrbt', 'ldrd', 'ldrex', 'ldrexb', 'ldrexd', 'ldrexh', 'ldrh',
    'ldrsb', 'ldrsh', 'ldrt', 'lsl', 'lsr', 'mcr', 'mcr2', 'mcrr', 'mcrr2', 'mla',
    'mov', 'mov', 'mov', 'mrc', 'mrc2', 'mrrc', 'mrrc2', 'mrs', 'msr', 'msr',
    'mul', 'mvn', 'nop', 'orr', 'pkhbt', 'pkhtb', 'pld', 'pop', 'pop', 'push',
    'push', 'qadd', 'qadd16', 'qadd8', 'qasx', 'qdadd', 'qdsub', 'qsax', 'qsub', 'qsub16',
    'qsub8', 'rev', 'rev16', 'revsh', 'rfe', 'ror', 'rrx', 'rsb', 'rsc', 'sadd16',
    'sadd8', 'sasx', 'sbc', 'sel', 'setend', 'sev', 'shadd16', 'shadd8', 'shasx', 'shsax',
    'shsub16', 'shsub8', 'smla', 'smlad', 'smlal', 'smlal', 'smlald', 'smlaw', 'smlsd', 'smlsld',
    'smmla', 'smmls', 'smmul', 'smuad', 'smul', 'smull', 'smulw', 'smusd', 'srs', 'ssat',
    'ssat16', 'ssax', 'ssub16', 'ssub8', 'stc', 'stc2', 'stm', 'stm', 'stm', 'stm',
    'str', 'strb', 'strbt', 'strd', 'strex', 'strexb', 'strexd', 'strexh', 'strh', 'strt',
    'sub', 'svc', 'swi', 'swp', 'swpb', 'sxtab', 'sxtab16', 'sxtah', 'sxtb', 'sxtb16',
    'sxth', 'teq', 'tst', 'uadd16', 'uadd8', 'uasx', 'udf', 'uhadd16', 'uhadd8', 'uhasx',
    'uhsax', 'uhsub16', 'uhsub8', 'umaal', 'umlal', 'umull', 'uqadd16', 'uqadd8', 'uqasx', 'uqsax',
    'uqsub16', 'uqsub8', 'usad8', 'usada8', 'usat', 'usat16', 'usax', 'usub16', 'usub8', 'uxtab',
    'uxtab16', 'uxtah', 'uxtb', 'uxtb16', 'uxth', 'wfe', 'wfi', 'yield'
  ].freeze

  CONDITION = [:illegal, :eq, :ne, :hs, :lo, :mi, :pl, :vs, :vc, :hi, :ls, :ge, :lt, :gt, :le, :al].freeze

  REGISTER = [:r0, :r1, :r2, :r3, :r4, :r5, :r6, :r7, :r8, :r9, :r10, :r11, :r12, :sp, :lr, :pc].freeze

  SHIFT = [:lsl, :lsr, :asr, :ror, :rrx].freeze

  CO_REG = [:c0, :c1, :c2, :c3, :c4, :c5, :c6, :c7, :c8, :c9, :c10, :c11, :c12, :c13, :c14, :c15].freeze

  STATUS_REG = [:cpsr, :spsr].freeze

  ARGUMENT_KIND = [
    :none, :reg, :reg_list, :co_reg, :status_reg, :status_mask, :shift, :shift_imm, :shift_reg,
    :u_imm, :sat_imm, :s_imm, :offset_imm, :offset_reg, :branch_dest, :co_option, :co_opcode,
    :coproc_num, :cpsr_mode, :cpsr_flags, :endian
  ].freeze

  ENDIAN = [:le, :be].freeze # illegal=255

  CONDITION_MAP     = CONDITION.each_with_index.to_h
  REGISTER_MAP      = REGISTER.each_with_index.to_h
  SHIFT_MAP         = SHIFT.each_with_index.to_h
  CO_REG_MAP        = CO_REG.each_with_index.to_h
  STATUS_REG_MAP    = STATUS_REG.each_with_index.to_h
  ARGUMENT_KIND_MAP = ARGUMENT_KIND.each_with_index.to_h
  ENDIAN_MAP        = ENDIAN.each_with_index.to_h

  class RegList < FFI::Struct
    layout :regs,      :uint32, # bitfield of registers
           :user_mode, :bool # access user-mode registers from elevated mode

    def contains?(register)
      register = REGISTER_MAP[register] if register.is_a? Symbol
      raise 'Invalid register' if register.nil? || (register.is_a?(Integer) && register >= REGISTER_MAP.length)
      self[:regs] & (1 << register) != 0
    end

    def user_mode?
      self[:user_mode]
    end
  end

  class Reg < FFI::Struct
    layout :deref,     :bool, # use as a base register
           :reg,       :uint8, # Register
           :writeback, :bool # when used as a base register, update this register's value

    def deref?
      self[:deref]
    end

    def reg
      return :illegal if self[:reg] == 255
      REGISTER[self[:reg]]
    end

    def writeback?
      self[:writeback]
    end
  end

  class StatusMask < FFI::Struct
    layout :control,    :bool, # control field mask (c)
           :extension,  :bool, # extension field mask (x)
           :flags,      :bool, # flags field mask (f)
           :reg,        :uint8, # StatusReg
           :status,     :bool # status field mask (s)

    def control?
      self[:control]
    end

    def extension?
      self[:extension]
    end

    def flags?
      self[:flags]
    end

    def reg
      return :illegal if self[:reg] == 255
      REGISTER[self[:reg]]
    end

    def status?
      self[:status]
    end
  end

  class ShiftImm < FFI::Struct
    layout :imm, :uint32, # immediate shift offset
           :op,  :uint8 # Shift

    def imm
      self[:imm]
    end
    alias_method :value, :imm

    def op
      SHIFT[self[:op]]
    end
  end

  class ShiftReg < FFI::Struct
    layout :op, :uint8, # Shift
           :reg, :uint8 # Register

    def op
      return :illegal if self[:op] == 255
      SHIFT[self[:op]]
    end

    def reg
      return :illegal if self[:reg] == 255
      REGISTER[self[:reg]]
    end
  end

  class OffsetImm < FFI::Struct
    layout :post_indexed, :bool, # if true, add offset to base register and write-back AFTER derefencing base register
           :value,        :int32 # offset value

    def post_indexed?
      self[:post_indexed]
    end

    def value
      self[:value]
    end
    alias_method :offset, :value
  end

  class OffsetReg < FFI::Struct
    layout :add,          :bool, # if true, add offset to base register, otherwise subtract
           :post_indexed, :bool, # if true, add offset to base register and write-back AFTER derefencing base register
           :reg,          :uint8 # Register

    def add?
      self[:add]
    end

    def post_indexed?
      self[:post_indexed]
    end

    def reg
      return :illegal if self[:reg] == 255
      REGISTER[self[:reg]]
    end
  end

  class CpsrMode < FFI::Struct
    layout :mode,      :uint32, # mode bits
           :writeback, :bool # writeback to base register

    def mode
      self[:mode]
    end
    alias_method :bits, :mode

    def writeback?
      self[:writeback]
    end
  end

  class CpsrFlags < FFI::Struct
    layout :a,      :bool, # imprecise data abort
           :enable, :bool, # enable the A/I/F flags if true otherwise disable
           :f,      :bool, # FIQ interrupt
           :i,      :bool  # IRQ interrupt

    def abort?
      self[:a]
    end

    def enable?
      self[:enable]
    end

    def fiq_interrupt?
      self[:f]
    end

    def irq_interrupt?
      self[:i]
    end
  end

  class ArgumentValue < FFI::Union
    layout :reg,         Reg,
           :reg_list,    RegList,
           :co_reg,      :uint8,
           :status_reg,  :uint8,
           :status_mask, StatusMask,
           :shift,       :uint8,
           :shift_imm,   ShiftImm,
           :shift_reg,   ShiftReg,
           :u_imm,       :uint32,
           :sat_imm,     :uint32,
           :s_imm,       :int32,
           :offset_imm,  OffsetImm,
           :offset_reg,  OffsetReg,
           :branch_dest, :int32,
           :co_option,   :uint32,
           :co_opcode,   :uint32,
           :coproc_num,  :uint32,
           :cpsr_mode,   CpsrMode,
           :cpsr_flags,  CpsrFlags,
           :endian,      :uint8

    def co_reg
      CO_REG[self[:co_reg]]
    end

    def status_reg
      STATUS_REG[self[:status_reg]]
    end

    def shift
      SHIFT[self[:shift]]
    end

    def endian
      return :illegal if self[:endian] == 255
      ENDIAN[self[:endian]]
    end
  end

  class Argument < FFI::Struct
    layout :kind, :uint8,
           :value, ArgumentValue

    def kind
      ARGUMENT_KIND[self[:kind]]
    end

    def value
      raise "No value for argument of kind 'none'" if kind == :none
      self[:value][kind]
    end
  end

  class Arguments < FFI::AutoPointer
    include Enumerable

    def self.release(ptr)
      UnarmBind.free_ins_args(ptr, 6)
    end

    def [](index)
      raise IndexError, 'there are 6 args' if index < 0 || index >= 6
      Argument.new(self + index * Argument.size)
    end

    def each
      return enum_for(:each) unless block_given?
      6.times { |i| yield self[i] }
    end

  end

  Arg = Argument
  Args = Arguments

  class CStr < FFI::AutoPointer
    def self.release(ptr)
      UnarmBind.free_c_str(ptr)
    end

    def to_s
      self.read_string
    end
  end

end


module Unarm
  extend UnarmBind

  module CPU
    ARM9 = :arm9 # ARMv5Te
    ARM7 = :arm7 # ARMv4T
  end

  @cpu = CPU::ARM9
  @symbols9 = nil
  @symbols7 = nil
  @raw_syms = {}

  def self.use_arm9
    @cpu = CPU::ARM9
  end

  def self.use_arm7
    @cpu = CPU::ARM7
  end

  def self.cpu = @cpu

  def self.symbols9 = @symbols9
  def self.symbols7 = @symbols7

  def self.symbols
    @cpu == CPU::ARM9 ? symbols9 : symbols7
  end

  def self.raw_syms = @raw_syms

  def self.shitty_demangle(sym)
    return sym unless sym.start_with?('_Z')

    sym = sym[2..]

    is_vtable = false

    if sym.start_with? 'N'
      sym = sym[1..]

    elsif sym.start_with? 'NK'
      sym = sym[2..]

    elsif sym.start_with? 'TV'
      sym = sym[2..]
      is_vtable = true

    elsif sym.start_with? 'nw'
      return 'new'

    elsif sym.start_with? 'na'
      return 'new[]'

    elsif sym.start_with? 'dl'
      return 'delete'

    elsif sym.start_with? 'da'
      return 'delete[]'
    end

    names = []
    loop do
      break if sym.nil? || sym.empty? || !sym[0].match?(/\d/)
      len_end = sym.index(/\D/)
      n_len   = Integer(sym[...len_end], exception: false)
      n       = sym[len_end, n_len]
      names   << n
      sym     = sym[len_end + n_len..]
    end

    names.join('::') + (is_vtable ? '::vtable' : '')
  end

  class Symbol < FFI::Struct
    layout :name, :pointer,
           :addr, :uint32
  end

  class Symbols
    attr_reader :map, :locs, :count, :demangled_map

    def self.load(file_path)
      syms = {} # maps symbol names to their addresses
      locs = {} # maps symbol names to their code locations (e.g. arm9, ov0, ov10)
      dest = nil # current symbol location
      File.open(file_path) do |f|
        f.each_line do |line|
          parts = line.split

          next if parts.length < 3
          
          is_comment = line.strip.start_with?('/')
          if is_comment
            new_dest = parts[1].split('_')
            dest = new_dest[new_dest.length == 1 ? 0 : 1] if new_dest[0].include?('arm')
            next
          end

          next if is_comment || (line.length < 4)

          parts.delete_at(1) # removes '='
          parts = parts[0..1] # keep symbol and name

          parts[1] = parts[1].chomp(';') if parts[1].end_with?(';')

          addr = parts[1].hex
          next if addr <= 0
          parts[1] = addr # - (addr & 1)
          syms[parts[0]] = parts[1]
          if dest
            locs[dest] = Array.new unless locs[dest]
            locs[dest] << parts[0]
          end

        end
      end
      return syms, locs
    end

    def initialize(args = {})
      if args.has_key? :file_path
        @map, @locs = Symbols.load(args[:file_path])
      elsif args.has_key? :syms
        @map, @locs = args[:syms].map, args[:syms].locs
      else
        raise ArgumentError, 'Symbols must be initialized through a file or a hash'
      end

      if args.has_key? :locs
        all_syms = @map
        @map = {}
        args[:locs].each do |loc|
          @locs[loc].each { |sym| @map[sym] = all_syms[sym] }
        end
      end

      @count = @map.length

      @demangled_map = {}
      @map.each do |sym, _addr|
        @demangled_map[Unarm.shitty_demangle(sym)] = sym
      end
    end

  end

  class RawSymbols # symbols that can be passed to Rust
    attr_reader :ptr, :count

    def initialize(syms)
      @count = syms.count
      @ptr = FFI::MemoryPointer.new(Symbol, @count)
      sym_arr = @count.times.map do |i|
        Symbol.new(@ptr + i*Symbol.size)
      end
      @name_ptrs = [] # keeps memory for symbol names alive (?)
      syms.map.each_with_index do |(name, addr), i|
        name_ptr = FFI::MemoryPointer.from_string(name)
        @name_ptrs << name_ptr
        sym_arr[i][:name] = name_ptr
        sym_arr[i][:addr] = addr
      end
    end

  end

  def self.load_symbols9(file_path)
    @symbols9 = Symbols.new(file_path: file_path)
  end

  def self.load_symbols7(file_path)
    @symbols7 = Symbols.new(file_path: file_path)
  end

  def self.symbol_map
    if @cpu == CPU::ARM9
      raise 'Symbols9 not loaded' if !@symbols9
      @symbols9.map
    else
      raise 'Symbols7 not loaded' if !@symbols7
      @symbols7.map
    end
  end

  def self.get_raw_symbols(loc)
    syms = loc == 'arm7' ? @symbols7 : @symbols9
    loc = 'arm9' if !syms.locs.has_key?(loc)
    locs = %w[arm7 arm9].include?(loc) ? [loc] : ['arm9', loc]
    @raw_syms[loc] ||= RawSymbols.new(Symbols.new(syms: syms, locs: locs))
  end

  class << self
    alias_method :sym_map, :symbol_map
    alias_method :get_raw_syms, :get_raw_symbols
  end

  class Ins
    include UnarmBind

    class << self
      alias_method :disasm, :new
    end

    attr_reader :raw, :opcode_id, :arguments, :address

    alias_method :op_id, :opcode_id
    alias_method :args, :arguments
    alias_method :addr, :address

    def size
      @@size
    end
    alias_method :ins_size, :size

    def string
      @str.to_s
    end
    alias_method :str, :string

    def eql?(other)
      @raw == other.raw
    end
    alias_method :==, :eql?

    def opcode
      UnarmBind::OPCODE[@op_id]
    end

    def mnemonic
      UnarmBind::OPCODE_MNEMONIC[@op_id]
    end

    def is_conditional?
      @conditional
    end
    alias_method :conditional?, :is_conditional?

    def is_unconditional?
      !@conditional
    end
    alias_method :unconditional?, :is_unconditional?

    def is_data_operation?
      @data_op
    end
    alias_method :is_data_op?, :is_data_operation?

    def is_illegal?
      opcode == :illegal
    end
    alias_method :illegal?, :is_illegal?

    def sets_flags?
      @sets_flags
    end
    alias_method :updates_condition_flags?, :sets_flags?

    def has_imod? # does instruction modify interrupt flags?
      opcode == :cps
    end

    def branch_destination
      arg = @arguments.find {|a| a.kind == :branch_dest}
      return nil if !arg
      arg.value + @address
    end
    alias_method :branch_dest, :branch_destination

    def target_address
      if opcode == :ldr && args[1].kind == :reg && args[1].value.reg == :pc && args[2].kind == :offset_imm
        address + args[2].value.value + 8
      else
        nil
      end
    end
    alias_method :target_addr, :target_address

    def branch_to_register?
      opcode == :bx ||
        (mnemonic == 'mov' && args[0].value.reg == :pc) || (mnemonic == 'ldr' && args[0].value.reg == :pc)
    end
    alias_method :branch_to_reg?, :branch_to_register?

    # this won't catch everything but I think it's good enough
    def function_end?
      return false if conditional?

      branch_to_register? ||
        (mnemonic == 'pop' && args[1].contains?(:pc)) ||
        (mnemonic == 'ldm' && args[0].value.reg == :sp && args[1].value.contains?(:pc))
    end

  end

  class ArmIns < Ins
    @@size = 4

    def initialize(ins, addr = 0, loc = Unarm.cpu.to_s)
      @raw = ins
      @address = addr ? addr : nil
      @ptr = FFI::AutoPointer.new(send(:"#{Unarm.cpu.to_s}_new_arm_ins", ins), method(:free_arm_ins))

      if Unarm.symbols
        syms = Unarm.get_raw_syms(loc)
        @str = CStr.new(send(:"#{Unarm.cpu.to_s}_arm_ins_to_str_with_syms", @ptr, syms.ptr, syms.count, addr, 0))
      else
        @str = CStr.new(send(:"#{Unarm.cpu.to_s}_arm_ins_to_str", @ptr))
      end

      @arguments = Arguments.new(send(:"#{Unarm.cpu.to_s}_arm_ins_get_args", @ptr))
      @op_id = send(:"#{Unarm.cpu.to_s}_arm_ins_get_opcode_id", @ptr)

      @conditional = arm_ins_is_conditional(@ptr)
      @data_op     = arm_ins_is_data_operation(@ptr)
      @sets_flags  = arm_ins_updates_condition_flags(@ptr)
    end

    def is_compare_operation? # does opcode compare a register with another value?
      [:cmn, :cmp, :teq, :tst].include? opcode
    end
    alias_method :is_compare_op?, :is_compare_operation?

  end

  class ThumbIns < Ins
    @@size = 2

    def initialize(ins, addr = 0, loc = Unarm.cpu.to_s)
      @raw = ins
      @address = addr ? addr : nil
      @ptr = FFI::AutoPointer.new(send(:"#{Unarm.cpu.to_s}_new_thumb_ins", ins), method(:free_thumb_ins))

      if Unarm.symbols
        syms = Unarm.get_raw_syms(loc)
        @str = CStr.new(send(:"#{Unarm.cpu.to_s}_thumb_ins_to_str_with_syms", @ptr, syms.ptr, syms.count, addr, 0))
      else
        @str = CStr.new(send(:"#{Unarm.cpu.to_s}_thumb_ins_to_str", @ptr))
      end

      @arguments = Arguments.new(send(:"#{Unarm.cpu.to_s}_thumb_ins_get_args", @ptr))
      @op_id = send(:"#{Unarm.cpu.to_s}_thumb_ins_get_opcode_id", @ptr)

      @conditional = thumb_ins_is_conditional(@ptr)
      @data_op     = thumb_ins_is_data_operation(@ptr)
      @sets_flags  = thumb_ins_updates_condition_flags(@ptr)
    end

  end

  class Parser
    include UnarmBind

    attr_reader :mode

    module Mode
      ARM   = 0
      THUMB = 1
      DATA  = 2
    end

    module Endian
      LITTLE = 0
      BIG    = 1
    end

    def set_parse_mode(mode)
      raise ArgumentError, 'mode must be ARM, THUMB, or DATA' unless (Mode::ARM..Mode::DATA).include? mode
      @mode = mode
    end

    def initialize(data_ptr, data_size, addr, mode = Mode::ARM, endian = Endian::LITTLE)
      set_parse_mode(mode)
      # TODO!!!!!
    end

  end

  class Data
    include UnarmBind

    attr_reader :raw, :size, :address, :location, :string, :value

    alias_method :addr, :address
    alias_method :loc, :location
    alias_method :str, :string

    def get_directive(size)
      case size
      when 4
        '.word'
      when 2
        '.hword'
      when 1
        '.byte'
      else
        raise "Could not determine directive from data size: #{size}"
      end
    end

    def initialize(raw, size: 4, addr: 0, loc: Unarm.cpu.to_s, might_be_ptr: true)
      @raw = raw
      @address = addr
      @location = loc
      if raw.is_a? String
        @size = raw.length + 1
        @string = ".asciiz \"#{raw}\""
      else
        @size = size
        if size == 4 && might_be_ptr
          syms = Unarm.get_raw_syms(loc)
          raw_str = CStr.new(get_sym_for_addr(raw, syms.ptr, syms.count))
          value = raw_str.null? ? raw.to_hex : raw_str.to_s
        else
          value = raw.to_hex
        end
        @string = "#{get_directive(size)} #{value}"
        @value = value
      end
    end

    def eql?(other)
      @raw == other.raw
    end
    alias_method :==, :eql?

  end

end
