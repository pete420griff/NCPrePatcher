require 'ffi'

class Integer
  def to_hex
    '0x' + self.to_s(16)
  end
end

module NitroBind
  extend FFI::Library
  ffi_lib ['nitro', Dir.pwd + '/nitro']

  attach_function :nitroRom_alloc, [], :pointer
  attach_function :nitroRom_release, [:pointer], :void
  attach_function :nitroRom_load, [:pointer, :string], :bool
  attach_function :nitroRom_getSize, [:pointer], :size_t
  attach_function :nitroRom_getHeader, [:pointer], :pointer
  attach_function :nitroRom_getFile, [:pointer, :uint32], :pointer
  attach_function :nitroRom_getFileSize, [:pointer, :uint32], :uint32
  attach_function :nitroRom_loadArm9, [:pointer], :pointer
  attach_function :nitroRom_loadArm7, [:pointer], :pointer
  attach_function :nitroRom_loadOverlay, [:pointer, :uint32], :pointer
  attach_function :nitroRom_getOverlayCount, [:pointer], :uint32

  attach_function :headerBin_alloc, [], :pointer
  attach_function :headerBin_release, [:pointer], :void
  attach_function :headerBin_load, [:pointer, :string], :bool
  attach_function :headerBin_getGameTitle, [:pointer], :string
  attach_function :headerBin_getGameCode, [:pointer], :string
  attach_function :headerBin_getMakerCode, [:pointer], :string
  attach_function :headerBin_getArm9AutoLoadHookOffset, [:pointer], :uint32
  attach_function :headerBin_getArm7AutoLoadHookOffset, [:pointer], :uint32
  attach_function :headerBin_getArm9EntryAddress, [:pointer], :uint32
  attach_function :headerBin_getArm7EntryAddress, [:pointer], :uint32
  attach_function :headerBin_getArm9RamAddress, [:pointer], :uint32
  attach_function :headerBin_getArm7RamAddress, [:pointer], :uint32

  attach_function :codeBin_read64, [:pointer, :uint32], :uint64
  attach_function :codeBin_read32, [:pointer, :uint32], :uint32
  attach_function :codeBin_read16, [:pointer, :uint32], :uint16
  attach_function :codeBin_read8, [:pointer, :uint32], :uint8
  attach_function :codeBin_getSize, [:pointer], :uint32
  attach_function :codeBin_getStartAddress, [:pointer], :uint32

  attach_function :armBin_alloc, [], :pointer
  attach_function :armBin_release, [:pointer], :void
  attach_function :armBin_load, [:pointer, :string, :uint32, :uint32, :uint32, :bool], :bool
  attach_function :armBin_getEntryPointAddress, [:pointer], :uint32

  attach_function :overlayBin_alloc, [], :pointer
  attach_function :overlayBin_release, [:pointer], :void
  attach_function :overlayBin_load, [:pointer, :string, :uint32, :bool, :int32], :bool

end

module UnarmBind
  extend FFI::Library
  ffi_lib ['unarm', Dir.pwd + '/unarm']

  attach_function :disasm_arm_ins, [:uint32], :string
  attach_function :free_c_str, [:string], :void

end

module Nitro
  extend NitroBind

  class CodeBin
    include NitroBind

    def read64(address)
      codeBin_read64(@ptr, address)
    end

    def read32(address)
      codeBin_read32(@ptr, address)
    end

    def read16(address)
      codeBin_read16(@ptr, address)
    end

    def read8(address)
      codeBin_read8(@ptr, address)
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

  end

  class Rom
    include NitroBind

    class << self
      alias_method :load, :new
    end

    attr_reader :header, :arm9, :arm7, :overlays, :overlay_count

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

  class Ins

    class << self
      alias_method :disasm, :new
    end

    attr_reader :str, :raw
    alias_method :string, :str

  end

  class ArmIns < Ins
    include UnarmBind

    def initialize(ins)
      @raw = ins
      @str = disasm_arm_ins(ins)
    end

  end

  class ThumbIns < Ins
    include UnarmBind

    def initialize(ins)
      @raw = ins
      # TODO
    end

  end

end


if $PROGRAM_NAME == __FILE__
  rom = Nitro::Rom.load(ARGV.length == 0 ? "NSMB.nds" : ARGV[0])
  puts "Game title: #{rom.header.game_title}"
  puts "Game code: #{rom.header.game_code}"
  puts "Maker code: #{rom.header.maker_code}"
  puts "Size: #{(rom.size / 1024.0 / 1024.0).round(2)} MB"
  puts "Arm9 at #{rom.arm9.start_addr.to_hex}: " + rom.arm9.read32(rom.arm9.start_addr).to_hex
  puts "Overlay count: #{rom.overlay_count}"
  puts "Ov0 at #{rom.ov0.start_addr.to_hex}: " + rom.overlay0.read32(rom.overlay0.start_addr).to_hex

  puts "Ov10 at #{rom.ov10.start_addr.to_hex}: " + Unarm::ArmIns.new(rom.ov10.read32(rom.ov10.start_addr)).string
end
