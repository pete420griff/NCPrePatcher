require_relative '../nitro/nitro.rb'
require_relative '../unarm/unarm.rb'

module NCPP
  module Utils
    def self.valid_identifier_check(name) # checks if given name is a valid command/variable name
      raise "Invalid identifier: #{name}" unless name.start_with?(/[A-Za-z_]/)
    end

    def self.gen_hook_str(type, addr, ov, asm=nil) # generates an NCPatcher hook
      "ncp_#{type}(#{addr.to_hex}#{",#{ov}"if ov}#{",\"#{asm}\"" if asm})"
    end
  end
end

class Integer
  def to_hex
    '0x' + self.to_s(16)
  end
end

class Proc
  def returns(type)
    define_singleton_method(:return_type) { type }
    self
  end
  def return_type
    nil
  end

  def cacheable
    define_singleton_method(:cacheable?) { true }
    self
  end
  def cacheable?
    false
  end
end

class Nitro::CodeBin

  def each_arm_instruction(range = bounds)
    each_word(range) do |word, addr|
      yield Unarm::ArmIns.disasm(word, addr, respond_to?(:id) ? "ov#{id}" : Unarm.cpu.to_s)
    end
  end
  alias_method :each_arm_ins, :each_arm_instruction
  alias_method :each_ins, :each_arm_instruction

  def each_thumb_instruction(range = bounds)
    each_hword(range) do |hword, addr|
      yield Unarm::ThumbIns.disasm(hword, addr, respond_to?(:id) ? "ov#{id}" : Unarm.cpu.to_s)
    end
  end
  alias_method :each_thumb_ins, :each_thumb_instruction

  def disasm_function(addr)
    mode = addr & 1 != 0 ? 'thumb' : 'arm'
    instructions = []
    pool = []
    send(:"each_#{mode}_ins", addr..) do |ins|
      raise "Illegal instruction found at #{ins.addr}; #{addr.to_hex} is likely not a function." if ins.illegal?
      # TODO
      instructions << ins
    end

    @functions[:addr] = {
      thumb?: mode == 'thumb',
      instructions: instructions,
      literal_pool: pool,
    }
  end
  
end
