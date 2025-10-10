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
    null: -> (*_) {},

    place: ->(arg) { arg }.returns(Object),

    if: ->(out,cond) { cond ? (out.is_a?(Block) ? out.call : out) : nil }.returns(Object),

    elsif: ->(out, cond, alt_out) {
      out.nil? ? (cond ? (alt_out.is_a?(Block) ? alt_out.call : alt_out) : nil ) : out
    }.returns(Object),

    else: ->(out, alt_out) {
      out.nil? ? (alt_out.is_a?(Block) ? alt_out.call : alt_out) : (out.is_a?(Block) ? out.call : out)
    }.returns(Object),

    then: ->(arg, block, *args) {
      raise "then expects a block" unless block.is_a?(Block)
      if block.args.nil?
        block.call
      elsif arg.nil?
        block.call(*args)
      else
        block.call(arg, *args)
      end
    }.returns(Object),

    do: ->(block, *args) {
      raise "do expects a block" unless block.is_a?(Block)
      block.call(*args)
    }.returns(Object),

    repeat: ->(block, count, *args) {
      raise "repeat expects a block" unless block.is_a?(Block)
      if block.args.nil?
        count.to_i.times { block.call }
      else
        count.to_i.times { |i| block.call(i, *args) } # make this a separate command?
      end
    },

    print: ->(msg, add_newline=true) {
      if add_newline
        puts msg
      else
        print msg
      end
    },

    warn: ->(msg) { warn "WARNING: #{msg}" },
    error: ->(msg) { raise msg },

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
    concat: ->(s1,s2) { s1.to_s + s2.to_s }.returns(String).cacheable,
    str_literal: ->(str) { '"' + str.to_s + '"' }.returns(String).cacheable,
    raw_str_literal: ->(str) { 'R"(' + "\n" + str.to_s + ')"' }.returns(String).cacheable,
    add_newline: ->(str) { str.to_s + "\n" }.returns(String).cacheable,

    array: ->(*args) { Array([*args]) }.returns(Array).cacheable,
    to_c_array: ->(arr) { Utils::to_c_array(arr) }.returns(String).cacheable,

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
    sym_from_index: ->(idx) { Unarm.sym_map.to_a[idx][0] }.returns(String).cacheable,

    get_function: ->(addr,ov=nil) { Utils::reloc_func(addr, ov) }.returns(String).cacheable,
    get_instruction: ->(addr,ov=nil) { Utils::get_instruction(addr, ov).str }.returns(String).cacheable,
    get_dword: ->(addr,ov=nil) { Utils::get_dword(addr,ov) }.returns(Integer).cacheable,
    get_word:  ->(addr,ov=nil) { Utils::get_word(addr,ov) }.returns(Integer).cacheable,
    get_hword: ->(addr,ov=nil) { Utils::get_hword(addr,ov) }.returns(Integer).cacheable,
    get_byte:  ->(addr,ov=nil) { Utils::get_byte(addr,ov) }.returns(Integer).cacheable,
    get_signed_dword: ->(addr,ov=nil) { Utils::get_signed_dword(addr,ov) }.returns(Integer).cacheable,
    get_signed_word:  ->(addr,ov=nil) { Utils::get_signed_word(addr,ov) }.returns(Integer).cacheable,
    get_signed_hword: ->(addr,ov=nil) { Utils::get_signed_hword(addr,ov) }.returns(Integer).cacheable,
    get_signed_byte:  ->(addr,ov=nil) { Utils::get_signed_byte(addr,ov) }.returns(Integer).cacheable,
    get_cstring: ->(addr,ov=nil) { Utils::get_cstring(addr,ov) }.returns(String).cacheable,
    get_array: ->(addr,ov,e_type_id,e_count=1) { Utils::get_array(addr,ov,e_type_id,e_count) }.returns(Array).cacheable,
    get_c_array: ->(addr,ov,e_type_id,e_count=1) {
      Utils::to_c_array(Utils::get_array(addr,ov,e_type_id,e_count))
    }.returns(Array).cacheable,

    find_first_branch_to: ->(branch_dest, start_loc, start_ov=nil) {
      Utils::find_first_branch_to(branch_dest, start_loc,start_ov)
    }.returns(Integer).cacheable,

    next_addr: ->(current_addr,ov=nil) { Utils::next_addr(current_addr,ov) }.returns(Integer).cacheable,

    get_ins_mnemonic: ->(loc,ov=nil) { Utils::get_ins_mnemonic(loc,ov) }.returns(String).cacheable,
    get_ins_arg: ->(loc,ov,arg_index) { Utils::get_ins_arg(loc,ov,arg_index) }.returns(String).cacheable
    # get_ins_branch_dest: ->(loc,ov=nil) {}.returns(Integer).cacheable,
    # get_ins_target_addr: ->(loc,ov=nil) {}.returns(Integer).cacheable

  },

  aliases: {
    eql:      :equal,
    str:      :string,
    upper:    :upcase,
    lower:    :downcase,
    quoted:   :str_literal,
    minute:   :min,
    second:   :sec,
    get_func: :get_function,
    get_ins:  :get_instruction,
    get_u64:  :get_dword,
    get_s64:  :get_signed_dword,
    get_u32:  :get_word,
    get_s32:  :get_word,
    get_int:  :get_word,
    get_u16:  :get_hword,
    get_s16:  :get_signed_hword,
    get_u8:   :get_byte,
    get_s8:   :get_signed_byte,
    get_cstr: :get_cstring
  }).freeze


  CORE_VARIABLES = {
    NCPP_VERSION: VERSION,
    BUILD_DATE: Time.now.to_s,
    PI: Math::PI,
    u64:  0,
    u32:  1,
    u16:  2,
    u8:   3,
    s64:  4,
    s32:  5,
    fx32: 5,
    s16:  6,
    fx16: 6,
    s8:   7,
    ARM9: -1,
    ARM7: -1
  }.freeze

end
