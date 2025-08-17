require 'fileutils'
require 'rbconfig'
require 'open3'

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

LIB_EXT = case
          when OS.windows?
            '.dll'
          when OS.mac?
            '.dylib'
          else
            '.so'
          end

NITRO_BUILD_PATH = 'nitro/build/'
NITRO_LIB_NAME = 'nitro' + LIB_EXT

def config_nitro
  # Create build folder if it doesn't exist
  Dir.mkdir(NITRO_BUILD_PATH) unless Dir.exist? NITRO_BUILD_PATH
  # Configure CMake
  Dir.chdir(NITRO_BUILD_PATH) do
    out, status = Open3.capture2e('cmake', '..')
    puts out
    unless status.success?
      puts "Error: CMake command failed with status #{status.exitstatus}"
      raise "CMake configuration failed"
    end
  end
end

def build_nitro
  # Build
  Dir.chdir(NITRO_BUILD_PATH) do
    out, status = Open3.capture2e('cmake', '--build', '.', '--config', 'Release')
    puts out
    unless status.success?
      puts "Error: CMake command failed with status #{status.exitstatus}"
      raise "CMake build failed"
    end
  end
  # Move lib to main dir
  lib_path = NITRO_BUILD_PATH + (OS.windows? ? 'Release/' : '') + NITRO_LIB_NAME
  lib_dest = '../' + NITRO_LIB_NAME
  puts "Moving #{lib_path} to #{lib_dest}"
  begin
    FileUtils.move lib_path, lib_dest
  rescue
    puts "Error: file not found at #{lib_path}"
  end
end

if $PROGRAM_NAME == __FILE__
  config_nitro unless Dir.exist? NITRO_BUILD_PATH and ARGV[0] != '--config'
  build_nitro
end
