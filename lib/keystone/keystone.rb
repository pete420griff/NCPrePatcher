require 'ffi'

require_relative 'arm_const'
require_relative 'keystone_const'
require_relative 'version'

module KeystoneBind
  extend FFI::Library
  ffi_lib [
    File.expand_path("keystone", __dir__),
    File.expand_path("keystone.dylib", __dir__),
    File.expand_path("keystone.so", __dir__),
  ]

  typedef :pointer, :ks_engine
  typedef :pointer, :ks_engine_handle
  typedef :uint, :ks_arch
  typedef :uint, :ks_err
  typedef :uint, :ks_opt_type

  attach_function :ks_version, [:pointer, :pointer], :uint
  attach_function :ks_arch_supported, [:ks_arch], :bool
  attach_function :ks_open, [:ks_arch, :int, :ks_engine_handle], :ks_err
  attach_function :ks_close, [:ks_engine], :ks_err
  attach_function :ks_errno, [:ks_engine], :ks_err
  attach_function :ks_strerror, [:ks_err], :string
  attach_function :ks_option, [:ks_engine, :ks_opt_type, :size_t], :ks_err
  attach_function :ks_asm, [:ks_engine, :string, :uint64, :pointer, :pointer, :pointer], :int
  attach_function :ks_free, [:pointer], :void
end

module Keystone
  extend KeystoneBind

  def self.major_version
    ks_version(nil, nil)
  end

  def self.arch_supported?(ks_arch)
    ks_arch_supported(ks_arch)
  end

  class Assembler
    include KeystoneBind

    def initialize(arch: KS_ARCH_ARM, mode: KS_MODE_ARM)

      FFI::MemoryPointer.new(:pointer,1) do |ptr|
        safe_call(:ks_open, arch, mode, ptr)
        @engine = FFI::AutoPointer.new(ptr.read_pointer, method(:ks_close))
      end
    end

    def assemble(asm_str, addr: 0)
      encoding_ptr = FFI::MemoryPointer.new(:pointer)
      encoding_size = FFI::MemoryPointer.new(:size_t)
      stat_count = FFI::MemoryPointer.new(:size_t)
      safe_call(:ks_asm, @engine, asm_str, addr, encoding_ptr, encoding_size, stat_count)
      encoded_bytes = encoding_ptr.read_pointer.read_array_of_uint8(encoding_size.read_uint)
      ks_free(encoding_ptr.read_pointer)
      encoded_bytes.pack('C*')
    end

    def set_option(ks_opt_type, value)
      safe_call(:ks_option, @engine, ks_opt_type, value)
    end

  private
    def safe_call(meth_sym, *args)
      err = send(meth_sym, *args)
      raise "Error from #{meth_sym}: #{ks_strerror(err)}" if err != KS_ERR_OK
    end
  end
end

Ks = Keystone
