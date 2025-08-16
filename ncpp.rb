require 'ffi'

class Integer
  def to_hex
    '0x' + self.to_s(16)
  end
end

module NitroBind
  extend FFI::Library
  ffi_lib ['nitro.dll', Dir.pwd + '/nitro.dll', 'nitro.dylib', 'nitro.so']

  attach_function :nitroRom_alloc, [], :pointer
  attach_function :nitroRom_release, [:pointer], :void
  attach_function :nitroRom_load, [:pointer, :string], :bool
  attach_function :nitroRom_getSize, [:pointer], :size_t
  attach_function :nitroRom_getHeader, [:pointer], :pointer
  attach_function :nitroRom_loadArm9, [:pointer], :pointer
  attach_function :nitroRom_loadArm7, [:pointer], :pointer

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

  attach_function :armBin_alloc, [], :pointer
  attach_function :armBin_release, [:pointer], :void

  attach_function :overlayBin_alloc, [], :pointer
  attach_function :overlayBin_release, [:pointer], :void
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
  end

  class ArmBin < CodeBin
    include NitroBind

    def initialize(args = {})
      if args.has_key? :file_path
        @ptr = FFI::AutoPointer.new(armBin_alloc, NitroBind.method(:armBin_release))
        armBin_load(@ptr, args[:file_path], args[:entry_addr], args[:ram_addr], args[:auto_load_hook_offset], args[:is_arm9] || true)

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

    attr_reader :header, :arm9, :arm7

    def initialize(file_path)
      @ptr = FFI::AutoPointer.new(nitroRom_alloc, NitroBind.method(:nitroRom_release))
      nitroRom_load(@ptr, file_path)
      @header = HeaderBin.new(nitroRom_getHeader(@ptr))
      @arm9 = ArmBin.new(ptr: FFI::AutoPointer.new(nitroRom_loadArm9(@ptr), NitroBind.method(:armBin_release)))
      @arm7 = ArmBin.new(ptr: FFI::AutoPointer.new(nitroRom_loadArm7(@ptr), NitroBind.method(:armBin_release)))
    end

    def size
      nitroRom_getSize(@ptr)
    end

  end

end


if $PROGRAM_NAME == __FILE__
  rom = Nitro::Rom.load(ARGV.length == 0 ? "NSMB.nds" : ARGV[0])
  puts "Game title: #{rom.header.game_title}"
  puts "Game code: #{rom.header.game_code}"
  puts "Maker code: #{rom.header.maker_code}"
  puts "Size: #{(rom.size / 1024.0 / 1024.0).round(2)} MB"
  puts "Arm9 at 0x1ff8000: " + rom.arm9.read32(0x01ff8000).to_hex
end
