require 'fileutils'
require 'rbconfig'
require 'open3'

module OS
  def self.windows?
    (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end

  def self.mac?
    (/darwin/ =~ RUBY_PLATFORM) != nil
  end

  def self.unix?
    !OS.windows?
  end

  def self.linux?
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


ROOT = File.expand_path(__dir__) # directory containing build.rb

NITRO_BUILD_PATH = File.join(ROOT, 'nitro/build/')
NITRO_LIB_NAME = (OS.unix? ? 'libnitro' : 'nitro') + LIB_EXT

UNARM_BUILD_PATH = File.join(ROOT, 'unarm/')
UNARM_LIB_NAME = (OS.unix? ? 'libunarm_c' : 'unarm_c') + LIB_EXT

VCPKG_TRIPLET = case
                when OS.windows?
                  'x64-windows'
                when OS.linux?
                  'x64-linux-dynamic'
                when OS.mac?
                  "#{RUBY_PLATFORM.start_with?('arm64') ? 'arm64' : 'x64'}-osx-dynamic"
                end

VCPKG_ROOT = ENV.has_key?("VCPKG_ROOT") ? ENV['VCPKG_ROOT'] : './vcpkg'
VCPKG_LIB_PATH = File.join(VCPKG_ROOT, "installed/#{VCPKG_TRIPLET}/#{OS.windows? ? 'bin' : 'lib'}/")


def config_nitro
  # Create build folder if it doesn't exist
  FileUtils.mkdir_p(NITRO_BUILD_PATH) unless Dir.exist? NITRO_BUILD_PATH
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
  lib_dest = File.join(ROOT, '../lib/nitro/nitro' + LIB_EXT)
  puts "Moving #{lib_path} to #{lib_dest}"
  begin
    FileUtils.move(lib_path, lib_dest)
  rescue
    puts "Error: file not found at #{lib_path}"
  end
end

def build_unarm
  Dir.chdir(UNARM_BUILD_PATH) do
    out, status = Open3.capture2e('cargo', 'build', '--release')
    puts out
    unless status.success?
      puts "Error: Cargo command failed with status #{status.exitstatus}"
      raise "Cargo build failed"
    end
  end

  lib_path = UNARM_BUILD_PATH + 'target/release/' + UNARM_LIB_NAME
  lib_dest = File.join(ROOT, '../lib/unarm/unarm' + LIB_EXT)
  puts "Moving #{lib_path} to #{lib_dest}"
  begin
    FileUtils.move(lib_path, lib_dest)
  rescue
    puts "Error: file not found at #{lib_path}"
  end
end

def build_vcpkg_lib(lib_name)
  out, status = Open3.capture2e('vcpkg', 'install', lib_name, "--overlay-triplets=#{lib_name}/triplets")
  puts out
  unless status.success?
    puts "Error: vcpkg command failed with status #{status.exitstatus}"
    raise "Vcpkg #{lib_name} build failed"
  end

  lib_path = File.join(VCPKG_LIB_PATH, (OS.windows? ? '' : 'lib') + lib_name + LIB_EXT)
  lib_dest = File.join(ROOT, "../lib/#{lib_name}/#{lib_name + LIB_EXT}")
  FileUtils.copy(lib_path, lib_dest)
end


if $PROGRAM_NAME == __FILE__
  if !Dir.exist?(NITRO_BUILD_PATH) || ARGV.include?('--config')
    config_nitro
  end

  if ARGV.include? 'nitro'
    build_nitro
    return
  end

  if ARGV.include? 'unarm'
    build_unarm
    return
  end

  if ARGV.include? 'unicorn'
    build_vcpkg_lib('unicorn')
    return
  end

  if ARGV.include? 'keystone'
    build_vcpkg_lib('keystone')
    return
  end

  build_nitro
  puts
  build_unarm
  puts
  build_vcpkg_lib('unicorn')
  puts
  build_vcpkg_lib('keystone')
end
