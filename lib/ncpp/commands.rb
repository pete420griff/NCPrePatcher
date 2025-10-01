require_relative 'utils.rb'
require_relative 'version.rb'

module NCPP

  COMMAND_PREFIX = 'ncpp_'

  class CommandRegistry < Hash
    def initialize(commands, aliases: {})
      @aliases = aliases
      h = commands.dup

      aliases.each do |alias_name, target|
        h[alias_name] = h[target]
      end

      super()
      merge!(h)
    end
  end

  CORE_COMMANDS = CommandRegistry.new({
    put: ->(x) { String(x) }.returns(String),

    if: ->(out,cond) { cond ? (out.is_a?(Block) ? out.call : out) : nil }.returns(Object),

    elsif: ->(out, cond, alt_out) {
      out.nil? ? (cond ? (alt_out.is_a?(Block) ? alt_out.call : alt_out) : nil ) : out
    }.returns(Object),

    else: ->(out, alt_out) {
      out.nil? ? (alt_out.is_a?(Block) ? alt_out.call : alt_out) : (out.is_a?(Block) ? out.call : out)
    }.returns(Object),

    then: ->(_, block, *args) {
      raise "then expects a block" unless block.is_a?(Block)
      block.call(*args)
    },

    do: ->(block, *args) {
      raise "do expects a block" unless block.is_a?(Block)
      block.call(*args)
    },

    repeat: ->(block, count) {
      raise "repeat expects a block" unless block.is_a?(Block)
      count.to_i.times { block.call }
    },

    console_log: ->(msg, add_newline=true) {
      if add_newline
        puts msg
      else
        print msg
      end
    },

    float: ->(n) { Float(n) }.returns(Float).cacheable,
    int: ->(n) { Integer(n) }.returns(Integer).cacheable,
    is_even: ->(i) { i.to_i.even? }.cacheable,
    is_odd: ->(i) { i.to_i.odd? }.cacheable,
    is_nil: ->(x) { x.nil? }.cacheable,
    equal: ->(x, y) { x == y }.cacheable,
    not_equal: ->(x, y) { x != y }.cacheable,

    hex: ->(i) { i.to_hex }.returns(String).cacheable,
    string: ->(x) { String(x) }.returns(String).cacheable,
    strlen: ->(s) { s.length }.returns(Integer).cacheable,
    upcase:   ->(str) { str.upcase }.returns(String).cacheable,
    downcase: ->(str) { str.downcase }.returns(String).cacheable,

    year:  -> { Time.now.year }.returns(Integer),
    month: -> { Time.now.month }.returns(Integer),
    day:   -> { Time.now.day }.returns(Integer),
    hour:  -> { Time.now.hour }.returns(Integer),
    min:   -> { Time.now.min }.returns(Integer),
    sec:   -> { Time.now.sec }.returns(Integer),

    rand: ->(n1=nil,n2=nil) {
      n1.nil? ? Random.rand() : (n2.nil? ? Random.rand(n1) : Random.rand(n1..n2))
    }.returns(Numeric),

    add: ->(a,b) { a + b }.returns(Numeric).cacheable,
    sub: ->(a,b) { a - b }.returns(Numeric).cacheable,
    mul: ->(a,b) { a * b }.returns(Numeric).cacheable,
    div: ->(a,b) { a / b }.returns(Numeric).cacheable,
    mod: ->(a,b) { a % b }.returns(Numeric).cacheable,
    sin: ->(n) { Math.sin(n) }.returns(Float).cacheable,
    cos: ->(n) { Math.cos(n) }.returns(Float).cacheable,
    tan: ->(n) { Math.tan(n) }.returns(Float).cacheable,
    exp: ->(n) { Math.exp(n) }.returns(Float).cacheable,
    log: ->(n) { Math.log(n) }.returns(Float).cacheable,
    sqrt: ->(n) { Math.sqrt(n) }.returns(Float).cacheable,

    over:      ->(addr,ov=nil) { Utils::gen_hook_str('over', addr, ov) }.returns(String).cacheable,
    hook:      ->(addr,ov=nil) { Utils::gen_hook_str('hook', addr, ov) }.returns(String).cacheable,
    call:      ->(addr,ov=nil) { Utils::gen_hook_str('call', addr, ov) }.returns(String).cacheable,
    jump:      ->(addr,ov=nil) { Utils::gen_hook_str('jump', addr, ov) }.returns(String).cacheable,
    thook:     ->(addr,ov=nil) { Utils::gen_hook_str('thook', addr, ov) }.returns(String).cacheable,
    tcall:     ->(addr,ov=nil) { Utils::gen_hook_str('tcall', addr, ov) }.returns(String).cacheable,
    tjump:     ->(addr,ov=nil) { Utils::gen_hook_str('tjump', addr, ov) }.returns(String).cacheable,
    set_hook:  ->(addr,ov=nil) { Utils::gen_hook_str('set_hook', addr, ov) }.returns(String).cacheable,
    set_call:  ->(addr,ov=nil) { Utils::gen_hook_str('set_call', addr, ov) }.returns(String).cacheable,
    set_jump:  ->(addr,ov=nil) { Utils::gen_hook_str('set_jump', addr, ov) }.returns(String).cacheable,
    set_thook: ->(addr,ov=nil) { Utils::gen_hook_str('set_thook', addr, ov) }.returns(String).cacheable,
    set_tcall: ->(addr,ov=nil) { Utils::gen_hook_str('set_tcall', addr, ov) }.returns(String).cacheable,
    set_tjump: ->(addr,ov=nil) { Utils::gen_hook_str('set_tjump', addr, ov) }.returns(String).cacheable,
    repl:      ->(addr, ov_or_asm, asm=nil) {
      Utils.gen_hook_str('repl', addr, ov_or_asm.is_a?(String) ? nil : ov_or_asm, asm.nil? ? ov_or_asm : asm)
    }.returns(String).cacheable,

    addr_to_sym: ->(addr,ov=nil) { Utils::addr_to_sym(addr, ov) }.returns(String).cacheable,
    sym_to_addr: ->(sym) { Utils::sym_to_addr(sym) }.returns(Integer).cacheable,
    get_sym_ov: ->(sym) { Utils::get_sym_ov(sym) }.returns(Integer).cacheable,

    get_function: ->(addr,ov=nil) { Utils::reloc_func(addr, ov) }.returns(String).cacheable,
    get_dword: ->(addr,ov=nil) { Utils::get_dword(addr,ov) }.returns(Integer).cacheable,
    get_word:  ->(addr,ov=nil) { Utils::get_word(addr,ov) }.returns(Integer).cacheable,
    get_hword: ->(addr,ov=nil) { Utils::get_hword(addr,ov) }.returns(Integer).cacheable,
    get_byte:  ->(addr,ov=nil) { Utils::get_byte(addr,ov) }.returns(Integer).cacheable,
    get_signed_dword: ->(addr,ov=nil) { Utils::get_signed_dword(addr,ov) }.returns(Integer).cacheable,
    get_signed_word:  ->(addr,ov=nil) { Utils::get_signed_word(addr,ov) }.returns(Integer).cacheable,
    get_signed_hword: ->(addr,ov=nil) { Utils::get_signed_hword(addr,ov) }.returns(Integer).cacheable,
    get_signed_byte:  ->(addr,ov=nil) { Utils::get_signed_byte(addr,ov) }.returns(Integer).cacheable

  },

  aliases: {
    out:       :put,
    eql:       :equal,
    str:       :string,
    upper:     :upcase,
    lower:     :downcase,
    minute:    :min,
    second:    :sec,
    get_func:  :get_function,
    copy_func: :get_function,
    get_u64:   :get_dword,
    get_s64:   :get_signed_dword,
    get_u32:   :get_word,
    get_s32:   :get_word,
    get_u16:   :get_hword,
    get_s16:   :get_signed_hword,
    get_u8:    :get_byte,
    get_s8:    :get_signed_byte
  }).freeze


  CORE_VARIABLES = {
    NCPP_VERSION: VERSION,
    BUILD_DATE: Time.now.to_s,
    PI: Math::PI
  }.freeze

end
