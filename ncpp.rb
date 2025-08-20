require 'ffi'

class Integer
  def to_hex
    '0x' + self.to_s(16)
  end
end

module NitroBind
  extend FFI::Library
  ffi_lib ['nitro', Dir.pwd + '/nitro']

  typedef :pointer, :rom_handle
  typedef :pointer, :header_handle
  typedef :pointer, :codebin_handle
  typedef :pointer, :ovte_handle

  attach_function :nitroRom_alloc, [], :rom_handle
  attach_function :nitroRom_release, [:rom_handle], :void
  attach_function :nitroRom_load, [:rom_handle, :string], :bool
  attach_function :nitroRom_getSize, [:rom_handle], :size_t
  attach_function :nitroRom_getHeader, [:rom_handle], :header_handle
  attach_function :nitroRom_getFile, [:rom_handle, :uint32], :pointer
  attach_function :nitroRom_getFileSize, [:rom_handle, :uint32], :uint32
  attach_function :nitroRom_loadArm9, [:rom_handle], :codebin_handle
  attach_function :nitroRom_loadArm7, [:rom_handle], :codebin_handle
  attach_function :nitroRom_loadOverlay, [:rom_handle, :uint32], :codebin_handle
  attach_function :nitroRom_getOverlayCount, [:rom_handle], :uint32
  attach_function :nitroRom_getArm9OvT, [:rom_handle], :ovte_handle

  attach_function :headerBin_alloc, [], :header_handle
  attach_function :headerBin_release, [:header_handle], :void
  attach_function :headerBin_load, [:header_handle, :string], :bool
  attach_function :headerBin_getGameTitle, [:header_handle], :string
  attach_function :headerBin_getGameCode, [:header_handle], :string
  attach_function :headerBin_getMakerCode, [:header_handle], :string
  attach_function :headerBin_getArm9AutoLoadHookOffset, [:header_handle], :uint32
  attach_function :headerBin_getArm7AutoLoadHookOffset, [:header_handle], :uint32
  attach_function :headerBin_getArm9EntryAddress, [:header_handle], :uint32
  attach_function :headerBin_getArm7EntryAddress, [:header_handle], :uint32
  attach_function :headerBin_getArm9RamAddress, [:header_handle], :uint32
  attach_function :headerBin_getArm7RamAddress, [:header_handle], :uint32
  attach_function :headerBin_getArm9OvTSize, [:header_handle], :uint32

  attach_function :codeBin_read64, [:codebin_handle, :uint32], :uint64
  attach_function :codeBin_read32, [:codebin_handle, :uint32], :uint32
  attach_function :codeBin_read16, [:codebin_handle, :uint32], :uint16
  attach_function :codeBin_read8, [:codebin_handle, :uint32], :uint8
  attach_function :codeBin_getSize, [:codebin_handle], :uint32
  attach_function :codeBin_getStartAddress, [:codebin_handle], :uint32

  attach_function :armBin_alloc, [], :codebin_handle
  attach_function :armBin_release, [:codebin_handle], :void
  attach_function :armBin_load, [:codebin_handle, :string, :uint32, :uint32, :uint32, :bool], :bool
  attach_function :armBin_getEntryPointAddress, [:codebin_handle], :uint32

  attach_function :overlayBin_alloc, [], :codebin_handle
  attach_function :overlayBin_release, [:codebin_handle], :void
  attach_function :overlayBin_load, [:codebin_handle, :string, :uint32, :bool, :int32], :bool

end

module UnarmBind
  extend FFI::Library
  ffi_lib ['unarm', Dir.pwd + '/unarm']

  typedef :pointer, :ins_handle
  typedef :pointer, :cstr_handle
  typedef :pointer, :parser_handle

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

  attach_function :arm9_arm_get_opcode_id, [:ins_handle], :uint16
  attach_function :arm7_arm_get_opcode_id, [:ins_handle], :uint16
  attach_function :arm9_thumb_get_opcode_id, [:ins_handle], :uint16
  attach_function :arm7_thumb_get_opcode_id, [:ins_handle], :uint16

  attach_function :arm_ins_is_conditional, [:ins_handle], :bool
  attach_function :thumb_ins_is_conditional, [:ins_handle], :bool

  attach_function :arm_ins_updates_condition_flags, [:ins_handle], :bool
  attach_function :thumb_ins_updates_condition_flags, [:ins_handle], :bool

  attach_function :free_arm_ins, [:ins_handle], :void
  attach_function :free_thumb_ins, [:ins_handle], :void
  attach_function :arm9_free_parser, [:parser_handle], :void
  attach_function :arm7_free_parser, [:parser_handle], :void
  attach_function :free_c_str, [:cstr_handle], :void

  # NOTE: some instructions here are not valid in ARMv5TE or v4T
  OPCODE = [
    :illegal, :adc, :add, :and, :asr, :b, :bl, :bic, :bkpt, :blx, :blx, :bx,
    :bxj, :cdp, :cdp2, :clrex, :clz, :cmn, :cmp, :cps, :csdb, :dbg, :eor,
    :ldc, :ldc2, :ldm, :ldm, :ldm, :ldm, :ldm, :ldm, :ldr, :ldrb, :ldrbt,
    :ldrd, :ldrex, :ldrexb, :ldrexd, :ldrexh, :ldrh, :ldrsb, :ldrsh, :ldrt,
    :lsl, :lsr, :mcr, :mcr2, :mcrr, :mcrr2, :mla, :mov, :mov, :mov, :mrc,
    :mrc2, :mrrc, :mrrc2, :mrs, :msr, :msr, :mul, :mvn, :nop, :orr, :pkhbt,
    :pkhtb, :pld, :pop, :pop, :push, :push, :qadd, :qadd16, :qadd8, :qasx, :qdadd,
    :qdsub, :qsax, :qsub, :qsub16, :qsub8, :rev, :rev16, :revsh, :rfe, :ror, :rrx,
    :rsb, :rsc, :sadd16, :sadd8, :sasx, :sbc, :sel, :setend, :sev, :shadd16, :shadd8,
    :shasx, :shsax, :shsub16, :shsub8, :smla, :smlad, :smlal, :smlal, :smlald, :smlaw,
    :smlsd, :smlsld, :smmla, :smmls, :smmul, :smuad, :smul, :smull, :smulw, :smusd, :srs,
    :ssat, :ssat16, :ssax, :ssub16, :ssub8, :stc, :stc2, :stm, :stm, :stm, :stm,
    :str, :strb, :strbt, :strd, :strex, :strexb, :strexd, :strexh, :strh, :strt, :sub,
    :svc, :swi, :swp, :swpb, :sxtab, :sxtab16, :sxtah, :sxtb, :sxtb16, :sxth, :teq,
    :tst, :uadd16, :uadd8, :uasx, :udf, :uhadd16, :uhadd8, :uhasx, :uhsax, :uhsub16, :uhsub8,
    :umaal, :umlal, :umull, :uqadd16, :uqadd8, :uqasx, :uqsax, :uqsub16, :uqsub8, :usad8, 
    :usada8, :usat, :usat16, :usax, :usub16, :usub8, :uxtab, :uxtab16, :uxtah, :uxtb, :uxtb16,
    :uxth, :wfe, :wfi, :yield
  ].freeze

  CONDITION = [
    :illegal, :eq, :ne, :hs, :lo, :mi, :pl, :vs, :vc, :hi, :ls, :ge, :lt, :gt, :le, :al
  ].freeze

  REGISTER = [
    :r0, :r1, :r2, :r3, :r4, :r5, :r6, :r7, :r8, :r9, :r10, :r11, :r12, :sp, :lr, :pc
  ].freeze

  SHIFT = [
    :lsl, :lsr, :asr, :ror, :rrx
  ].freeze

end

module Nitro
  extend NitroBind

  class OvtEntry < FFI::Struct
    layout :overlay_id,   :uint32,
           :ram_address,  :uint32,
           :ram_size,     :uint32,
           :bss_size,     :uint32,
           :sinit_start,  :uint32,
           :sinit_end,    :uint32,
           :file_id,      :uint32,
           :comp_field,   :uint32

    def ram_addr
      self[:ram_address]
    end

    def compressed_size
      (self[:comp_field] >> 8) & 0xffffff # 24 bits
    end

    def is_compressed?
      (self[:comp_field] & 0xff) == 1   # 8 bits
    end
    alias_method :compressed?, :is_compressed?

  end

  class OvtBin
    include NitroBind

    attr_reader :size, :entry_count

    def initialize(args = {})
      if args.has_key? :file_path
        bin = File.binread(args[:file_path])
        @size = bin.bytesize
        @ptr = FFI::MemoryPointer.new(:uint8, @size)
        @ptr.put_bytes(0, bin)

      elsif args.has_key? :ptr and args.has_key? :size
        @ptr = args[:ptr]
        @size = args[:size]
        @entry_count = @size / OvtEntry.size
      else
        raise ArgumentError
      end
    end

    def get_entry(id)
      raise IndexError if id > @entry_count-1
      OvtEntry.new(@ptr + id*OvtEntry.size)
    end

  end

  class CodeBin
    include NitroBind

    def read64(addr)
      codeBin_read64(@ptr, addr)
    end

    def read32(addr)
      codeBin_read32(@ptr, addr)
    end

    def read16(addr)
      codeBin_read16(@ptr, addr)
    end

    def read8(addr)
      codeBin_read8(@ptr, addr)
    end

    def size
      codeBin_getSize(@ptr)
    end

    def start_address
      codeBin_getStartAddress(@ptr)
    end
    alias_method :start_addr, :start_address

    def end_address
      start_address + size
    end
    alias_method :end_addr, :end_address

  end

  class ArmBin < CodeBin
    include NitroBind

    def initialize(args = {})
      if args.has_key? :file_path
        @ptr = FFI::AutoPointer.new(armBin_alloc, NitroBind.method(:armBin_release))
        if not File.exist? args[:file_path]
          puts "Error: #{args[:file_path]} does not exist"
          raise "ArmBin initialization failed"
        end
        armBin_load(@ptr, args[:file_path], args[:entry_addr], args[:ram_addr], args[:auto_load_hook_offset], args[:is_arm9] || true)

      elsif args.has_key? :ptr and args[:ptr].is_a? FFI::AutoPointer
        @ptr = args[:ptr]

      else
        raise ArgumentError
      end
    end

    def entry_point_address
      armBin_getEntryPointAddress(@ptr)
    end
    alias_method :entry_addr, :entry_point_address
    alias_method :entry_point_addr, :entry_point_address

  end

  class OverlayBin < CodeBin
    include NitroBind

    attr_reader :id

    def initialize(id, args = {})
      @id = id
      if args.has_key? :file_path
        @ptr = FFI::AutoPointer.new(overlayBin_alloc, NitroBind.method(:overlayBin_release))
        if not File.exist? args[:file_path]
          puts "Error: #{args[:file_path]} does not exist"
          raise "OverlayBin initialization failed"
        end
        overlayBin_load(@ptr, args[:file_path], args[:ram_addr], args[:is_compressed], @id)

      elsif args.has_key? :ptr and args[:ptr].is_a? FFI::AutoPointer
        @ptr = args[:ptr]

      else
        raise ArgumentError
      end
    end

  end

  class HeaderBin
    include NitroBind

    def initialize(arg)
      if arg.is_a? String
        @ptr = FFI::AutoPointer.new(headerBin_alloc, NitroBind.method(:headerBin_release))
        if not File.exist? arg
          puts "Error: #{arg} does not exist"
          raise "HeaderBin initialization failed"
        end
        headerBin_load(@ptr, arg)
      elsif arg.is_a? FFI::Pointer
        @ptr = arg
      end
    end

    def game_title
      headerBin_getGameTitle(@ptr)
    end

    def game_code
      headerBin_getGameCode(@ptr)
    end

    def maker_code
      headerBin_getMakerCode(@ptr)
    end

    def arm9_auto_load_hook_offset
      headerBin_getArm9AutoLoadHookOffset(@ptr)
    end
    alias_method :arm9_auto_load_hook_ofs, :arm9_auto_load_hook_offset

    def arm7_auto_load_hook_offset
      headerBin_getArm7AutoLoadHookOffset(@ptr)
    end
    alias_method :arm7_auto_load_hook_ofs, :arm7_auto_load_hook_offset

    def arm9_entry_address
      headerBin_getArm9EntryAddress(@ptr)
    end
    alias_method :arm9_entry_addr, :arm9_entry_address

    def arm7_entry_address
      headerBin_getArm7EntryAddress(@ptr)
    end
    alias_method :arm7_entry_addr, :arm7_entry_address

    def arm9_ram_address
      headerBin_getArm9RamAddress(@ptr)
    end
    alias_method :arm9_ram_addr, :arm9_ram_address
    
    def arm7_ram_address
      headerBin_getArm7RamAddress(@ptr)
    end
    alias_method :arm7_ram_addr, :arm7_ram_address

    def get_arm9_ovt_size
      headerBin_getArm9OvTSize(@ptr)
    end

  end

  class Rom
    include NitroBind

    class << self
      alias_method :load, :new
    end

    attr_reader :header, :arm9, :arm7, :overlays, :overlay_count, :overlay_table

    alias_method :ov_count, :overlay_count
    alias_method :ov_table, :overlay_table
    alias_method :ovt, :overlay_table

    def initialize(file_path)
      @ptr = FFI::AutoPointer.new(nitroRom_alloc, NitroBind.method(:nitroRom_release))
      if not File.exist? file_path
        puts "Error: #{file_path} does not exist"
        raise "Rom initialization failed"
      end
      nitroRom_load(@ptr, file_path)
      @header = HeaderBin.new(nitroRom_getHeader(@ptr))
      @arm9 = ArmBin.new(ptr: FFI::AutoPointer.new(nitroRom_loadArm9(@ptr), NitroBind.method(:armBin_release)))
      @arm7 = ArmBin.new(ptr: FFI::AutoPointer.new(nitroRom_loadArm7(@ptr), NitroBind.method(:armBin_release)))
      @overlay_count = nitroRom_getOverlayCount(@ptr)
      @overlays = Array.new(@overlay_count)
      @overlay_table = OvtBin.new(ptr: nitroRom_getArm9OvT(@ptr), size: @header.get_arm9_ovt_size)
      define_ov_accessors
    end

    def size
      nitroRom_getSize(@ptr)
    end

    def get_file(id)
      nitroRom_getFile(id)
    end

    def get_file_size(id)
      nitroRom_getFileSize(id)
    end

    def load_overlay(id)
      raise IndexError if id > @overlay_count-1
      @overlays[id] = OverlayBin.new(id, ptr: FFI::AutoPointer.new(nitroRom_loadOverlay(@ptr, id), NitroBind.method(:overlayBin_release)))
    end
    alias_method :load_ov, :load_overlay

    def get_overlay(id)
      raise IndexError if id > @overlay_count-1
      load_overlay(id) if @overlays[id] == nil
      @overlays[id]
    end
    alias_method :get_ov, :get_overlay

private
    def define_ov_accessors
      (0..@overlay_count-1).each do |id|
        self.class.define_method(:"overlay#{id}") do
          get_overlay(id)
        end
        self.class.define_method(:"ov#{id}") do
          get_overlay(id)
        end
      end
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

  def self.cpu
    @cpu
  end

  def self.use_arm9
    @cpu = CPU::ARM9
  end

  def self.use_arm7
    @cpu = CPU::ARM7
  end

  class CStr < FFI::AutoPointer
    def self.release(ptr)
      UnarmBind.free_c_str(ptr)
    end

    def to_s
      self.read_string
    end

  end

  class Ins
    class << self
      alias_method :disasm, :new
    end

    attr_reader :raw, :op_id

    alias_method :opcode_id, :op_id

    def string
      @str.to_s
    end
    alias_method :str, :string

    def opcode_mnemonic
      UnarmBind::OPCODE[@op_id].to_s
    end
    alias_method :opcode_string, :opcode_mnemonic
    alias_method :opcode_str, :opcode_mnemonic
    alias_method :op_string, :opcode_mnemonic
    alias_method :op_str, :opcode_mnemonic
    alias_method :op_mnemonic, :opcode_mnemonic

    def is_conditional?
      @conditional
    end
    alias_method :conditional?, :is_conditional?

    def sets_flags?
      @sets_flags
    end
    alias_method :updates_condition_flags?, :sets_flags?

  end

  class ArmIns < Ins
    include UnarmBind

    def initialize(ins)
      @raw = ins
      @ptr = FFI::AutoPointer.new(eval("#{Unarm.cpu.to_s}_new_arm_ins(ins)"), UnarmBind.method(:free_arm_ins))
      @str = CStr.new(eval("#{Unarm.cpu.to_s}_arm_ins_to_str(@ptr)"))
      @op_id = eval("#{Unarm.cpu.to_s}_arm_get_opcode_id(@ptr)")
      @conditional = arm_ins_is_conditional(@ptr)
      @sets_flags = arm_ins_updates_condition_flags(@ptr)
    end

  end

  class ThumbIns < Ins
    include UnarmBind

    def initialize(ins)
      @raw = ins
      @ptr = FFI::AutoPointer.new(eval("#{Unarm.cpu.to_s}_new_thumb_ins(ins)"), UnarmBind.method(:free_thumb_ins))
      @str = CStr.new(eval("#{Unarm.cpu.to_s}_thumb_ins_to_str(@ptr)"))
      @op_id = eval("#{Unarm.cpu.to_s}_thumb_get_opcode_id(@ptr)")
      @conditional = thumb_ins_is_conditional(@ptr)
      @sets_flags = thumb_ins_updates_condition_flags(@ptr)
    end

  end

  class Parser
    include UnarmBind
    # TODO
    module Mode
      ARM = 0
      THUMB = 1
      DATA = 2
    end
  end

end


if $PROGRAM_NAME == __FILE__
  rom = Nitro::Rom.load(ARGV.length == 0 ? "NSMB.nds" : ARGV[0])
  puts "Game title: #{rom.header.game_title}"
  puts "Game code: #{rom.header.game_code}"
  puts "Maker code: #{rom.header.maker_code}"
  puts "Size: #{(rom.size / 1024.0 / 1024.0).round(2)} MB"
  puts "Overlay count: #{rom.overlay_count}"

  # ovte = Nitro::OvtBin.new('arm9ovt.bin').get_entry(1)

  # puts ovte[:ram_address].to_hex
  # puts ovte.is_compressed?

  # ov1 = Nitro::OverlayBin.new(
  #   1, file_path: 'overlay9_1.bin', ram_addr: ovte[:ram_address], is_compressed: ovte.compressed?
  # )

  start_addr = rom.ov1.start_addr
  end_addr = rom.ov1.end_addr
  pc = start_addr
  puts 'Disassembling ov1...'
  f = File.new('ov1-disasm2.txt', 'w')
  until pc == end_addr do
    f.write("#{pc.to_hex}: ")
    f.puts(Unarm::ArmIns.disasm(rom.ov1.read32(pc)).str)
    pc += 4
  end
  f.close

  puts 'Done!'

end
