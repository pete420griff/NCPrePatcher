require_relative 'utils.rb'
require_relative 'version.rb'

module NCPP

  COMMAND_PREFIX = 'ncpp_'

  CORE_COMMANDS = {
    put: ->(x) { String(x) }.returns(String),

    if: ->(out,cond) { cond ? (out.is_a?(Block) ? out.call : out) : nil }.returns(Object),

    elsif: ->(out, cond, alt_out) { out.nil? ? (cond ? (alt_out.is_a?(Block) ? alt_out.call : alt_out) : nil ) : out }
      .returns(Object),

    else: ->(out, alt_out) do
      out.nil? ? (alt_out.is_a?(Block) ? alt_out.call : alt_out) : (out.is_a?(Block) ? out.call : out)
    end.returns(Object),

    then: ->(_, block) do
      raise "then expects a block" unless block.is_a?(Block)
      block.call
    end,

    do: ->(block) do
      raise "do expects a block" unless block.is_a?(Block)
      block.call
    end,

    repeat: ->(block, count) do
      raise "repeat expects a block" unless block.is_a?(Block)
      count.to_i.times { block.call }
    end,

    console_log: ->(msg) { puts msg },

    float: ->(n) { Float(n) }.returns(Float).cacheable,
    int: ->(n) { Integer(n) }.returns(Integer).cacheable,
    is_even: ->(i) { i.to_i.even? }.cacheable,
    is_odd: ->(i) { i.to_i.odd? }.cacheable,

    hex: ->(i) { i.to_hex }.returns(String).cacheable,
    str: ->(x) { String(x) }.returns(String).cacheable,
    strlen: ->(s) { s.length }.returns(Integer).cacheable,
    upcase:   ->(str) { str.upcase }.returns(String).cacheable,
    downcase: ->(str) { str.downcase }.returns(String).cacheable,

    year:  -> { Time.now.year }.returns(Integer),
    month: -> { Time.now.month }.returns(Integer),
    day:   -> { Time.now.day }.returns(Integer),
    hour:  -> { Time.now.hour }.returns(Integer),
    min:   -> { Time.now.min }.returns(Integer),
    sec:   -> { Time.now.sec }.returns(Integer),

    rand: ->(n1=nil,n2=nil) do
      n1.nil? ? Random.rand() : (n2.nil? ? Random.rand(n1) : Random.rand(n1..n2))
    end.returns(Numeric),

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
    repl:      ->(addr,ov_or_asm,asm=nil) do
      Utils.gen_hook_str('repl', addr, ov_or_asm.is_a?(String) ? nil : ov_or_asm, asm.nil? ? ov_or_asm : asm)
    end.returns(String).cacheable
  }.freeze


  CORE_VARIABLES = {
    NCPP_VERSION: VERSION,
    BUILD_DATE: Time.now.to_s,
    PI: Math::PI
  }.freeze

end
