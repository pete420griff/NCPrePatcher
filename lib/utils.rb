
class Integer
  def to_hex
    '0x' + self.to_s(16)
  end
end

class String
  def from_hex
    Integer(self,16)
  end
end
