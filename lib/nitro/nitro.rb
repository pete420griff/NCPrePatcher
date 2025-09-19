require 'ffi'

module NitroBind
  extend FFI::Library
  ffi_lib [
    File.expand_path("nitro", __dir__),
    File.expand_path("nitro.dylib", __dir__),
    File.expand_path("nitro.so", __dir__),
  ]

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

    def id
      self[:overlay_id]
    end

    def ram_addr
      self[:ram_address]
    end

    def sinit_bounds
      self[:sinit_start]..self[:sinit_end]
    end

    def fid
      self[:file_id]
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

      elsif args.has_key?(:ptr) && args.has_key?(:size)
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
    alias_method :read_dword, :read64

    def read32(addr)
      codeBin_read32(@ptr, addr)
    end
    alias_method :read_word, :read32

    def read16(addr)
      codeBin_read16(@ptr, addr)
    end
    alias_method :read_hword, :read16

    def read8(addr)
      codeBin_read8(@ptr, addr)
    end
    alias_method :read_byte, :read8

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

    def bounds
      start_addr..end_addr
    end

    def read(range = bounds, step = 4)
      raise ArgumentError, 'step must be 1, 2, or 4 (bytes)' unless [1,2,4].include? step
      raise ArgumentError, 'range must be a Range' unless range.is_a? Range

      clamped = Range.new([range.begin || start_addr, start_addr].max, [range.end || end_addr, end_addr].min)

      clamped.step(step).map { |addr| [send(:"read#{step * 8}", addr), addr] }
    end

    def each_word(range = bounds)
      read(range).each do |word, addr|
        yield word, addr
      end
    end

    def each_dword(range = bounds)
      read(range,8).each do |dword, addr|
        yield dword, addr
      end
    end

    def each_hword(range = bounds)
      read(range,2).each do |hword, addr|
        yield hword, addr
      end
    end

    def each_byte(range = bounds)
      read(range,1).each do |byte, addr|
        yield byte, addr
      end
    end

  end

  class ArmBin < CodeBin
    include NitroBind

    def initialize(args = {})
      if args.has_key? :file_path
        @ptr = FFI::AutoPointer.new(armBin_alloc, method(:armBin_release))
        if not File.exist? args[:file_path]
          puts "Error: #{args[:file_path]} does not exist"
          raise 'ArmBin initialization failed'
        end
        armBin_load(@ptr, args[:file_path], args[:entry_addr], args[:ram_addr], args[:auto_load_hook_offset],
                    args[:is_arm9] || true)

      elsif args.has_key?(:ptr) && args[:ptr].is_a?(FFI::AutoPointer)
        @ptr = args[:ptr]

      else
        raise ArgumentError, 'ArmBin must be initialized with a file or a pointer'
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
      if [:file_path, :ram_addr, :is_compressed].all? { |k| args.key?(k) }
        @ptr = FFI::AutoPointer.new(overlayBin_alloc, method(:overlayBin_release))
        if !File.exist? args[:file_path]
          puts "Error: #{args[:file_path]} does not exist"
          raise "OverlayBin initialization failed"
        end
        overlayBin_load(@ptr, args[:file_path], args[:ram_addr], args[:is_compressed], @id)

      elsif args.has_key?(:ptr) && args[:ptr].is_a?(FFI::AutoPointer)
        @ptr = args[:ptr]

      else
        raise ArgumentError, 'OverlayBin must be initialized with a file or a pointer'
      end
    end

  end

  class HeaderBin
    include NitroBind

    def initialize(arg)
      if arg.is_a? String
        @ptr = FFI::AutoPointer.new(headerBin_alloc, method(:headerBin_release))
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

    def arm9_ovt_size
      headerBin_getArm9OvTSize(@ptr)
    end

  end

  class Rom
    include NitroBind

    attr_reader :header, :arm9, :arm7, :overlays, :overlay_count, :overlay_table

    alias_method :ov_count, :overlay_count
    alias_method :ov_table, :overlay_table
    alias_method :ovt, :overlay_table

    def initialize(file_path)
      @ptr = FFI::AutoPointer.new(nitroRom_alloc, method(:nitroRom_release))

      # Check whether file exists here because if C++ throws an exception we get a segfault
      if !File.exist?(file_path)
        puts "Error: #{file_path} does not exist"
        raise "Rom initialization failed"
      end

      nitroRom_load(@ptr, file_path)
      @header = HeaderBin.new(nitroRom_getHeader(@ptr))
      @arm9 = ArmBin.new(ptr: FFI::AutoPointer.new(nitroRom_loadArm9(@ptr), method(:armBin_release)))
      @arm7 = ArmBin.new(ptr: FFI::AutoPointer.new(nitroRom_loadArm7(@ptr), method(:armBin_release)))
      @overlay_count = nitroRom_getOverlayCount(@ptr)
      @overlays = Array.new(@overlay_count)
      @overlay_table = OvtBin.new(ptr: nitroRom_getArm9OvT(@ptr), size: @header.arm9_ovt_size)
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
      ov_ptr = nitroRom_loadOverlay(@ptr, id)
      raise "Failed to load overlay #{id}." if !ov_ptr
      @overlays[id] = OverlayBin.new(id, ptr: FFI::AutoPointer.new(ov_ptr, method(:overlayBin_release)))
    end
    alias_method :load_ov, :load_overlay

    def get_overlay(id)
      raise IndexError if id > @overlay_count-1
      load_overlay(id) if @overlays[id].nil?
      @overlays[id]
    end
    alias_method :get_ov, :get_overlay

    def each_overlay
      @overlay_count.times do |i|
        yield get_overlay(i), i
      end
    end
    alias_method :each_ov, :each_overlay

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
