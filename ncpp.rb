require 'ffi'

module NitroBind
	extend FFI::Library
	ffi_lib 'libNitro.dylib'

	attach_function :nitroRom_alloc, [], :pointer
	attach_function :nitroRom_release, [ :pointer ], :void
	attach_function :nitroRom_load, [ :pointer, :string ], :bool
	attach_function :nitroRom_getSize, [ :pointer ], :size_t
	attach_function :nitroRom_getGameTitle, [ :pointer ], :string
end

module Nitro
	extend NitroBind

	class Rom
		include NitroBind

		def initialize(romFilePath)
			@ptr = FFI::AutoPointer.new(nitroRom_alloc, NitroBind.method(:nitroRom_release))
			nitroRom_load(@ptr, romFilePath)
		end

		def size
			nitroRom_getSize(@ptr)
		end

		def title
			nitroRom_getGameTitle(@ptr)
		end
	end

end


if $PROGRAM_NAME == __FILE__
	puts "Yo"
end
