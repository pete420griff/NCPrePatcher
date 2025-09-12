
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
end

module NCPP
  module Utils
    def self.valid_identifier_check(name)
      raise "Invalid identifier: #{name}" unless name.start_with?(/[A-Za-z_]/)
    end

    def self.gen_hook_str(type, addr, ov)
      "ncp_#{type}(#{addr.to_hex}#{",#{ov}"if ov})"
    end
  end
end
