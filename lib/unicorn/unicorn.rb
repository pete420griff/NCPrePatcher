require 'ffi'

require_relative 'arm_const.rb'
require_relative 'unicorn_const.rb'

include UnicornEngine

module UnicornBind
  extend FFI::Library
  ffi_lib [
    File.expand_path("unicorn", __dir__),
    File.expand_path("unicorn.dylib", __dir__),
    File.expand_path("unicorn.so", __dir__),
  ]

  typedef :pointer, :uc_engine        # ptr to uc_engine instance
  typedef :pointer, :uc_engine_handle # ptr to a uc_engine ptr
  typedef :pointer, :reg_val_ptr
  typedef :pointer, :reg_val_ptr_arr
  typedef :pointer, :reg_id_arr
  typedef :uint64,  :addr
  typedef :uint,    :uc_arch
  typedef :uint,    :uc_mode
  typedef :uint,    :uc_err
  typedef :uint,    :uc_query_type
  typedef :uint,    :uc_control_type
  typedef :int,     :reg_id

  attach_function :uc_version, [:pointer,:pointer], :uint
  attach_function :uc_arch_supported, [:uc_arch], :bool
  attach_function :uc_open, [:uc_arch, :uc_mode, :uc_engine_handle], :uc_err
  attach_function :uc_close, [:uc_engine], :uc_err
  attach_function :uc_query, [:uc_engine, :uc_query_type, :pointer], :uc_err
  attach_function :uc_ctl, [:uc_engine, :uc_control_type, :varargs], :uc_err
  attach_function :uc_errno, [:uc_engine], :uc_err
  attach_function :uc_strerror, [:uc_err], :string
  attach_function :uc_reg_write, [:uc_engine, :reg_id, :reg_val_ptr], :uc_err
  attach_function :uc_reg_read, [:uc_engine, :reg_id, :reg_val_ptr], :uc_err
  attach_function :uc_reg_write_batch, [:uc_engine, :reg_id_arr, :reg_val_ptr_arr, :int], :uc_err
  attach_function :uc_reg_read_batch, [:uc_engine, :reg_id_arr, :reg_val_ptr_arr, :int], :uc_err
  attach_function :uc_mem_write, [:uc_engine, :addr, :pointer, :uint64], :uc_err
  attach_function :uc_mem_read, [:uc_engine, :addr, :pointer, :uint64], :uc_err
  attach_function :uc_emu_start, [:uc_engine, :addr, :addr, :uint64, :size_t], :uc_err
  attach_function :uc_emu_stop, [:uc_engine], :uc_err
  attach_function :uc_mem_map, [:uc_engine, :addr, :uint64, :uint32], :uc_err
  attach_function :uc_mem_map_ptr, [:uc_engine, :addr, :uint64, :uint32, :pointer], :uc_err
  attach_function :uc_mem_unmap, [:uc_engine, :addr, :uint64], :uc_err
  attach_function :uc_mem_protect, [:uc_engine, :addr, :uint64, :uint32], :uc_err

  REG_ID = {
    r0:   UC_ARM_REG_R0,
    r1:   UC_ARM_REG_R1,
    r2:   UC_ARM_REG_R2,
    r3:   UC_ARM_REG_R3,
    r4:   UC_ARM_REG_R4,
    r5:   UC_ARM_REG_R5,
    r6:   UC_ARM_REG_R6,
    r7:   UC_ARM_REG_R7,
    r8:   UC_ARM_REG_R8,
    r9:   UC_ARM_REG_R9,
    r10:  UC_ARM_REG_R10,
    r11:  UC_ARM_REG_R11,
    r12:  UC_ARM_REG_R12,
    sp:   UC_ARM_REG_SP,
    lr:   UC_ARM_REG_LR,
    pc:   UC_ARM_REG_PC,
    cpsr: UC_ARM_REG_CPSR,
    spsr: UC_ARM_REG_SPSR
  }.freeze
end

module Unicorn
  extend UnicornBind

  class Region
    attr_reader :addr, :size, :prot, :end_addr
    def initialize(addr, size, prot = UC_PROT_ALL)
      @addr = addr
      @size = size
      @prot = prot
      @end_addr = addr + size
    end
  end

  NDS_REGIONS = [
    Region.new(0x1ff8000, 32*1024),      # ITCM         -> 32KB
    Region.new(0x2000000, 4*1024*1024),  # Main memory  -> 4MB
    Region.new(0x4000000, 64*1024*1024), # I/O and VRAM -> 64MB
    Region.new(0xffff000, 32*1024)       # BIOS         -> 32KB
  ].freeze

  class Section
    attr_reader :addr, :ptr, :size, :end_addr
    def initialize(addr, ffi_ptr, size)
      @addr = addr
      @ptr = ffi_ptr
      @size = size
      @end_addr = addr + size
    end
  end
  Sect = Section

  class Emulator
    include UnicornBind

    def initialize(arch: UC_ARCH_ARM, mode: UC_MODE_ARM946, regions: NDS_REGIONS, sections: [], registers: {})

      FFI::MemoryPointer.new(:pointer, 1) do |ptr|
        safe_call(:uc_open, arch, mode, ptr)
        @engine = FFI::AutoPointer.new(ptr.read_pointer, method(:uc_close))
      end

      regions.each { add_region(it) } unless regions.empty?
      sections.each { add_sect(it) } unless sections.empty?
      registers.each {|r,v| write_register(r,v) } unless registers.empty?
    end

    def run(from: nil, to: -1, timeout_ms: 0, max_ins: 0)
      raise "The 'from' parameter must be specified" if from.nil?
      if to == -1 && timeout_ms == 0 && max_ins == 0
        raise "The 'to' parameter must be specified if 'timeout_ms' or 'max_ins' are not"
      end
      safe_call(:uc_emu_start, @engine, from, to, timeout_ms, max_ins)
    end

    def add_region(region)
      safe_call(:uc_mem_map, @engine, region.addr, region.size, region.prot)
    end

    def add_section(sect)
      safe_call(:uc_mem_write, @engine, sect.addr, sect.ptr, sect.size)
    end
    alias_method :add_sect, :add_section

    def write_mem(addr, byte_str)
      FFI::MemoryPointer.new(:uint8, byte_str.bytesize) do |ptr|
        ptr.write_array_of_uint8(byte_str.bytes)
        safe_call(:uc_mem_write, @engine, addr, ptr, byte_str.bytesize)
      end
    end

    def read_mem(addr, size)
      byte_str = nil
      FFI::MemoryPointer.new(:uint8, size) do |ptr|
        safe_call(:uc_mem_read, @engine, addr, ptr, size)
        byte_str = ptr.read_array_of_uint8(size).pack('C*')
      end
      byte_str
    end

    def write_register(reg, val)
      FFI::MemoryPointer.new(:int32, 1) do |pv|
        pv.write_int(val)
        safe_call(:uc_reg_write, @engine, REG_ID[reg], pv)
      end
    end
    alias_method :write_reg, :write_register

    def write_registers(regs_h)
      regs_h.each {|r,v| write_register(r,v) }
    end
    alias_method :write_regs, :write_registers

    REG_ID.each do |name, id|
      define_method("write_#{name.to_s}".to_sym) do |val|
        write_register(name, val)
      end
    end

    def read_register(reg)
      val = nil
      FFI::MemoryPointer.new(:int32, 1) do |pv|
        safe_call(:uc_reg_read, @engine, REG_ID[reg], pv)
        val = pv.read_int32
      end
      val
    end
    alias_method :read_reg, :read_register

    def read_registers(reg_names = REG_ID.keys)
      regs_h = {}
      reg_names.each {|r| regs_h[r] = read_register(r) }
      regs_h
    end
    alias_method :read_regs, :read_registers

    REG_ID.each do |name, id|
      define_method("read_#{name.to_s}".to_sym) do
        read_register(name)
      end
    end

  private
    def safe_call(meth_sym, *args)
      err = send(meth_sym, *args)
      raise "Error from #{meth_sym.to_s}: #{uc_strerror(err)}" if err != UC_ERR_OK
    end
  end

  Emu = Emulator

end

Uc = Unicorn
