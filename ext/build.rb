
module OS
	def OS.windows?
		(/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
	end

	def OS.mac?
		(/darwin/ =~ RUBY_PLATFORM) != nil
	end

	def OS.unix?
		!OS.windows?
	end

	def OS.linux?
		OS.unix? and not OS.mac?
	end
end

module Build
	def generateCMake
	end
end

if $PROGRAM_NAME == __FILE__
	if not Dir.exist? 'nitro/build'
		Dir.mkdir('nitro/build')
	end
end
