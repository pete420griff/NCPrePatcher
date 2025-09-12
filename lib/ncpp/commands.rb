require_relative 'utils.rb'
require_relative 'version.rb'

module NCPP

  @@COMMAND_PREFIX = 'ncpp_'

  @@CORE_COMMANDS = {
    put: ->(x) { String(x) }.returns(String),

    if:    ->(out,cond) { cond ? (out.is_a?(Block) ? out.call : out) : nil }.returns(Object),
    elsif: ->(out, cond, alt_out) { out.nil? ? (cond ? (alt_out.is_a?(Block) ? alt_out.call : alt_out) : nil ) : out },
    else:  ->(out, alt_out) { out.nil? ? (alt_out.is_a?(Block) ? alt_out.call : alt_out) : (out.is_a?(Block) ? out.call : out) }.returns(Object),

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

    float: ->(n) { Float(n) }.returns(Float),
    int: ->(n) { Integer(n) }.returns(Integer),
    is_even: ->(i) { i.to_i.even? },
    is_odd: ->(i) { i.to_i.odd? },

    hex: ->(i) { i.to_hex }.returns(String),
    str: ->(x) { String(x) }.returns(String),
    strlen: ->(s) { s.length }.returns(Integer),
    upcase:   ->(str) { str.upcase }.returns(String),
    downcase: ->(str) { str.downcase }.returns(String),

    year:   -> { Time.now.year }.returns(Integer),
    month:  -> { Time.now.month }.returns(Integer),
    day:    -> { Time.now.day }.returns(Integer),
    hour:   -> { Time.now.hour }.returns(Integer),
    min:   -> { Time.now.min }.returns(Integer),
    sec:   -> { Time.now.sec }.returns(Integer),

    penis: ->(size=1) { '8' + '='*size + 'D' }.returns(String),

    rand: ->(n1=nil,n2=nil) { n1.nil? ? Random.rand() : (n2.nil? ? Random.rand(n1) : Random.rand(n1..n2)) }.returns(Numeric),
    add: ->(a,b) { a + b }.returns(Numeric),
    sub: ->(a,b) { a - b }.returns(Numeric),
    mul: ->(a,b) { a * b }.returns(Numeric),
    div: ->(a,b) { a / b }.returns(Numeric),
    mod: ->(a,b) { a % b }.returns(Numeric),
    sin: ->(n) { Math.sin(n) }.returns(Float),
    cos: ->(n) { Math.cos(n) }.returns(Float),
    tan: ->(n) { Math.tan(n) }.returns(Float),
    exp: ->(n) { Math.exp(n) }.returns(Float),
    log: ->(n) { Math.log(n) }.returns(Float),
    sqrt: ->(n) { Math.sqrt(n) }.returns(Float),

    over:      ->(addr,ov=nil) { Utils::gen_hook_str('over', addr, ov) }.returns(String),
    hook:      ->(addr,ov=nil) { Utils::gen_hook_str('hook', addr, ov) }.returns(String),
    call:      ->(addr,ov=nil) { Utils::gen_hook_str('call', addr, ov) }.returns(String),
    jump:      ->(addr,ov=nil) { Utils::gen_hook_str('jump', addr, ov) }.returns(String),
    thook:     ->(addr,ov=nil) { Utils::gen_hook_str('thook', addr, ov) }.returns(String),
    tcall:     ->(addr,ov=nil) { Utils::gen_hook_str('tcall', addr, ov) }.returns(String),
    tjump:     ->(addr,ov=nil) { Utils::gen_hook_str('tjump', addr, ov) }.returns(String),
    set_hook:  ->(addr,ov=nil) { Utils::gen_hook_str('set_hook', addr, ov) }.returns(String),
    set_call:  ->(addr,ov=nil) { Utils::gen_hook_str('set_call', addr, ov) }.returns(String),
    set_jump:  ->(addr,ov=nil) { Utils::gen_hook_str('set_jump', addr, ov) }.returns(String),
    set_thook: ->(addr,ov=nil) { Utils::gen_hook_str('set_thook', addr, ov) }.returns(String),
    set_tcall: ->(addr,ov=nil) { Utils::gen_hook_str('set_tcall', addr, ov) }.returns(String),
    set_tjump: ->(addr,ov=nil) { Utils::gen_hook_str('set_tjump', addr, ov) }.returns(String),
    repl:      ->(addr,ov_or_asm,asm=nil) { "ncp_repl(#{addr.to_hex}#{',' if ov_or_asm}#{'"' if !asm}#{ov_or_asm}#{asm ? ',' : '"'}#{"\"#{asm}\"" if asm})" }.returns(String)
  }.freeze


  @@CORE_VARIABLES = {
    NCPP_VERSION: VERSION,
    BUILD_DATE: Time.now.to_s,
    PI: Math::PI
  }.freeze

end
