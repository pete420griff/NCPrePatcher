# frozen_string_literal: true

require_relative 'types'
require_relative 'version'

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
    null: -> (*_) {}
      .describe('Takes any number of arguments, does nothing with them, and returns nothing.'),

    place: ->(arg) { arg }.returns(Object)
      .describe('Returns the given argument as is.'),

    unless: ->(out,cond,*args) { !cond ? (out.is_a?(Block) ? out.call(*args) : out) : nil }.returns(Object)
      .describe('Returns or calls the given argument if the given condition is false, otherwise returns nil.'),

    if: ->(out,cond,*args) { cond ? (out.is_a?(Block) ? out.call(*args) : out) : nil }.returns(Object)
      .describe('Returns or calls the given argument if the given condition is true, otherwise returns nil.'),

    elsif: ->(out, cond, alt_out, *args) {
      out.nil? ? (cond ? (alt_out.is_a?(Block) ? alt_out.call(*args) : alt_out) : nil ) : out
    }.returns(Object),
      # .describe('Returns the given argument if the condition is true'),

    else: ->(out, alt_out,*args) {
      out.nil? ? (alt_out.is_a?(Block) ? alt_out.call(*args) : alt_out) : (out.is_a?(Block) ? out.call(*args) : out)
    }.returns(Object),

    then: ->(arg, block, *args) {
      Utils.block_check(block, 'then')
      if block.arg_names.nil?
        block.call
      elsif arg.nil?
        block.call(*args)
      else
        block.call(arg, *args)
      end
    }.returns(Object),

    do: ->(block_or_arr, *args) {
      if block_or_arr.is_a?(Block) || block_or_arr.is_a?(Proc)
        block_or_arr.call(*args)
      elsif block_or_arr.is_a? Array
        out = args[0]
        block_or_arr.each do |block|
          out = out.nil? ? block.call : block.call(out)
        end
        out
      else
        raise "'do' expects a Block, or an Array of Blocks"
      end
    }.returns(Object)
     .describe("Calls the given Block with the given args, or an Array of Blocks sequentially with one arg."),

    time_it: ->(block, *args) {
      Utils.block_check(block, 'time_it')
      start_time = Time.now
      if args.nil?
        block.call
      else
        block.call(*args)
      end
      Time.now - start_time
    }.returns(Float).impure
      .describe('Calls the given Block and gets how long it takes to execute it.'),

    repeat: ->(block, count, *args) {
      Utils.block_check(block, 'repeat')
      if block.arg_names.nil?
        count.to_i.times { block.call }
      else
        count.to_i.times { |i| block.call(i, *args) } # make this a separate command?
      end
    }.describe('Calls Block the given number of times, with the current iteration number as the first Block argument.'),

    while: ->(block, cond_block) {
      block.call while cond_block.call
    }.describe('Repeatedly calls the given Block until the second Block returns false.'),

    until: ->(block, cond_block) {
      block.call until cond_block.call
    }.describe('Repeatedly calls the given Block until the second Block returns true.'),

    trampoline: ->(block) {
      block = block.call while block.is_a?(Block)
      block # not a Block at this point
    }.returns(Object)
      .describe(
        "Calls the given Block until it no longer returns a Block. Used for calling deep recursive commands without " \
        "blowing out the stack."
    ),

    try: ->(block, *args) {
      begin
        if args.nil?
          block.call
        else
          block.call(*args)
        end
      rescue
        nil
      end
    }.returns(Object).impure
      .describe(
        "Tries to execute and return the result of the given Block; if an exception is thrown it is caught, and nil " \
        "is returned."
    ),

    try_or_message: ->(block, *args) {
      begin
        if args.nil?
          block.call
        else
          block.call(*args)
        end
      rescue => e
        e
      end
    }.returns(Object).impure
      .describe(
        "Tries to execute and return the result of the given Block; if an exception is thrown it is caught, and the " \
        "exception message is returned."
    ),

    try_or: ->(block, alt) {
      begin
        block.call
      rescue
        alt.is_a?(Block) ? alt.call : alt
      end
    }.returns(Object).impure
      .describe(
        "Tries to execute the first given Block; if an exception is thrown, the second Block is executed instead."
    ),

    print: ->(msg, add_newline=true) {
      if add_newline
        puts msg
      else
        print msg
      end
    }.impure
      .describe('Prints the given message, optionally ending with a newline.'),

    info: ->(msg) { Utils.print_info(msg) }.impure
      .describe('Prints some informative message to the console.'),

    warn: ->(msg) { Utils.print_warning(msg) }.impure
      .describe('Prints a warning to the console with the given message.'),

    error: ->(msg) { raise msg }.impure
      .describe('Raises an error with the given message.'),

    breakpoint: -> { raise 'Breakpoint hit.' }.impure,

    assert: ->(msg, cond) { raise msg unless cond }.impure
      .describe('Raises an error with the given message if the provided condition is false.'),

    type_name: ->(obj) { obj.class.to_s }.returns(String)
      .describe('Gets the type name of the given object.'),

    is_a: ->(obj, type_str) { obj.class.to_s == type_str }.returns(Object)
      .describe('Gets whether the type of the given object matches the type described in the given String.'),

    float: ->(n) { Float(n) }.returns(Float)
      .describe('Gets the given argument as a Float.'),

    int: ->(n) { Integer(n) }.returns(Integer)
      .describe('Gets the given argument as an Integer.'),

    is_even: ->(i) { i.to_i.even? }.returns(Object)
      .describe('Gets whether given Integer is even.'),

    is_odd: ->(i) { i.to_i.odd? }.returns(Object)
      .describe('Gets whether given Integer is odd.'),

    is_between: ->(n, min,max) { n.between?(min,max) }.returns(Object)
      .describe('Gets whether number is between given min and max values.'),

    is_nil: ->(x) { x.nil? }.returns(Object)
      .describe('Gets whether given argument is nil.'),

    equal: ->(x, y) { x == y }.returns(Object)
      .describe('Gets whether arguments are equal.'),

    not_equal: ->(x, y) { x != y }.returns(Object)
      .describe('Gets whether arguments are not equal.'),

    hex: ->(i) { Utils.integer_check(i,'hex'); i.to_hex }.returns(String)
      .describe('Returns a hexadecimal representation of the given Integer.'),

    ord: ->(s) { s.ord }.returns(Integer)
      .describe('Gets the Integer ordinal of the first character in the given String.'),

    string: ->(x) { String(x) }.returns(String)
      .describe('Gets the given argument as a String.'),

    upcase: ->(str) { Utils.string_check(str,'upcase'); str.upcase }.returns(String)
      .describe('Gets the given String with all uppercase letters.'),

    downcase: ->(str) { Utils.string_check(str,'downcase'); str.downcase }.returns(String)
      .describe('Gets the given String with all lowercase letters.'),

    capitalize: ->(str) { Utils.string_check(str,'capitalize'); str.capitalize }.returns(String)
      .describe('Makes the first letter of the given String upcased, and the rest downcased.'),

    swapcase: ->(str) { Utils.string_check(str,'swapcase'); str.swapcase }.returns(String)
      .describe('Swaps the cases of each character in the given String.'),

    snake_case: ->(str) {
      Utils.string_check(str,'snake_case')
      str.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
    }.returns(String)
      .describe('Gets the given String in snake_case.'),

    screaming_snake_case: ->(str) {
      Utils.string_check(str,'screaming_snake_case')
      str.gsub(/([a-z])([A-Z])/, '\1_\2').upcase
    }.returns(String)
      .describe('Gets the given String in SCREAMING_SNAKE_CASE.'),

    camel_case: ->(str) {
      Utils.string_check(str,'camel_case')
      if str.include? '_'
        parts = str.split('_')
        parts.first + parts[1..].map(&:capitalize).join
      else
        str[0].downcase + str[1..]
      end
    }.returns(String)
      .describe('Gets the given String in camelCase.'),

    pascal_case: ->(str) {
      Utils.string_check(str,'pascal_case')
      if str.include? '_'
        parts = str.split('_')
        parts.map(&:capitalize).join
      else
        str[0].upcase + str[1..]
      end
    }.returns(String)
      .describe('Gets the given String in PascalCase.'),

    match: ->(str, pattern_str) { Utils.string_check(str,'match'); str.match(Regexp.new(pattern_str)).to_s }
      .returns(String)
      .describe('Gets a String containing the portion of the given String that matches the given regex pattern.'),

    matches: ->(str, pattern_str) { Utils.string_check(str,'matches'); str.match?(Regexp.new(pattern_str)) }
      .returns(Object)
      .describe('Gets whether a String matches the given regex pattern.'),

    starts_with: ->(str,start_str) { Utils.string_check(str,'starts_with'); str.start_with?(start_str) }.returns(Object)
      .describe('Gets whether String starts with other given String.'),

    gsub: ->(str, pattern_str, replacement='') {
      Utils.string_check(str,'gsub')
      str.gsub(Regexp.new(pattern_str), replacement)
    }.returns(String)
      .describe('Replaces all occurences of the given pattern in the given String with the given replacement.'),

    strip: ->(str) { Utils.string_check(str,'strip'); str.strip }.returns(String)
      .describe('Removes leading and trailing whitespace from the given String.'),

    lstrip: ->(str) { Utils.string_check(str,'lstrip'); str.lstrip }.returns(String)
      .describe('Removes leading whitespace from the given String.'),

    rstrip: ->(str) { Utils.string_check(str,'rstrip'); str.rstrip }.returns(String)
      .describe('Removes trailing whitespace from the given String.'),

    succ: ->(str) { Utils.string_check(str,'succ'); str.succ }.returns(String)
      .describe('Gets the successor of a String by incrementing characters.'),

    rjust: ->(str, size, pad_str=' ') { Utils.string_check(str,'rjust'); str.rjust(size,pad_str) }.returns(String)
      .describe('Gets a right-justified copy of given String.'),

    ljust: ->(str, size, pad_str=' ') { Utils.string_check(str,'ljust'); str.ljust(size,pad_str) }.returns(String)
      .describe('Gets a left-justified copy of given String.'),

    str_literal: ->(str) { '"' + str.to_s + '"' }.returns(String)
      .describe('Gets the given String as a C string literal'),

    raw_str_literal: ->(str) { 'R"(' + "\n" + str.to_s + ')"' }.returns(String)
      .describe('Gets the given String as a C++ raw string literal.'),

    add_newline: ->(str) { str.to_s + "\n" }.returns(String)
      .describe('Gets the given String with an added newline at the end.'),

    split: ->(str,sep=$;,limit=0) { Utils.string_check(str,'split'); str.split(sep,limit) }.returns(Array)
      .describe(
        "Gets an Array of substrings that are the result of splitting the given String at each occurence of the given" \
        " field separator. The amount of splits are limited to the given limit (if greater than 0)."
    ),

    unpack: ->(byte_str, template, offset = 0) {
      Utils.string_check(byte_str, 'unpack')
      byte_str.unpack(template, offset: offset)
    }.returns(Array)
      .describe(
        "Extracts data from byte String using provided template. See Ruby packed_data docs for how to format said " \
        "template."
    ),

    pack: ->(arr, template) {
      Utils.array_check(arr, 'pack')
      arr.pack(template)
    }.returns(String)
      .describe(
        "Formats elements in given Array into a binary String using provided template. See Ruby packed_data docs for " \
        "how to use said template."
    ),

    concat: ->(obj1,obj2) { Utils.check_response(obj1,:concat); obj1.concat(obj2) }.returns(Object)
      .describe('Concatenates two concatenable objects.'),

    length: ->(obj) { Utils.check_response(obj,:length); obj.length }.returns(Integer)
      .describe('Gets the length of the given object.'),

    reverse: ->(obj) { Utils.check_response(obj,:reverse); obj.reverse }.returns(Object)
      .describe('Gets the reverse of the given object.'),

    is_empty: ->(obj) { Utils.check_response(obj,:empty?); obj.empty? }.returns(Object)
      .describe('Gets whether the given argument is empty.'),

    prepend: ->(obj, *objs) { Utils.check_response(obj,:prepend); obj.prepend(*objs) }.returns(Object),

    includes: ->(obj1, obj2) { Utils.check_response(obj1, :include?); obj1.include? obj2 }.returns(Object)
      .describe('Gets whether the first given object contains the second.'),

    count: ->(obj,thing) {
      Utils.check_response(obj,:count)
      if obj.is_a?(Array) && thing.is_a?(Block)
        obj.count {|idx| thing.call(idx) }
      else
        obj.count(thing)
      end
    }.returns(Integer),

    slice: ->(obj, idx,len=nil) {
      Utils.check_response(obj,:slice)
      len.nil? ? obj.slice(idx) : obj.slice(idx,len)
    }.returns(Object),

    index: ->(obj,thing) {
      if obj.is_a? String
        obj.index(thing)
      elsif obj.is_a? Array
        if thing.is_a? Block
          obj.index {|element| thing.call(element) }
        else
          obj.index(thing)
        end
      else
        raise "'index' expects a String or an Array"
      end
    }.returns(Integer),

    rindex: ->(obj,thing) {
      if obj.is_a? String
        obj.rindex(thing)
      elsif obj.is_a? Array
        if thing.is_a? Block
          obj.rindex {|element| thing.call(element) }
        else
          obj.rindex(thing)
        end
      else
        raise "'rindex' expects a String or an Array"
      end
    }.returns(Integer),

    delete: ->(obj, thing) {
      if obj.is_a? String
        obj.delete(thing)
      elsif obj.is_a? Array
        obj.delete(thing)
        obj
      else
        raise "'delete' expects a String or an Array"
      end
    }.returns(Object),

    insert: ->(obj,idx,*objs) { Utils.check_response(obj,'insert'); obj.insert(idx,*objs) }.returns(Object),

    array: ->(*args) { Array([*args]) }.returns(Array)
      .describe('Creates an Array containing each given argument.'),

    range: ->(first_or_arr,last=nil) {
      if first_or_arr.is_a? Array
        first = first_or_arr[0]
        last = first_or_arr[1]
      else
        first = first_or_arr
      end
      (last.nil? ? 0..first : first..last).to_a
    }.returns(Array),

    compact: ->(arr) { Utils.array_check(arr,'compact'); arr.compact }.returns(Array)
      .describe('Gets the given Array with all nil elements removed.'),

    cycle: ->(arr, n, block) { Utils.array_check(arr,'cycle'); arr.cycle {|e| block.call(e) } }
      .describe('Calls the given Block with each element in Array, then does so again, until it has done so n times.'),

    drop: ->(arr, n) { Utils.array_check(arr,'drop'); arr.drop(n) }.returns(Array)
      .describe('Gets the given Array containing all but the first n elements.'),

    append: ->(arr, *objs) { Utils.array_check(arr,'append'); arr.append(*objs) }.returns(Array),
    rotate: ->(arr,count=1) { Utils.array_check(arr,'rotate'); arr.rotate(count) }.returns(Array),
    shuffle: ->(arr) { Utils.array_check(arr,'shuffle'); arr.shuffle }.returns(Array),
    zip: ->(arr, *arrs) { Utils.array_check(arr,'zip'); arr.zip(*arrs) }.returns(Array),
    flatten: ->(arr,depth=nil) { Utils.array_check(arr,'flatten'); arr.flatten(depth) }.returns(Array),
    values_at: ->(arr, *specs) { Utils.array_check(arr,'values_at'); arr.values_at(*specs) }.returns(Array),
    take: ->(arr,count) { Utils.array_check(arr,'take'); arr.take(count) }.returns(Array),

    take_while: ->(arr,block) {
      Utils.array_check(arr,'take_while')
      arr.take_while {|element| block.call(element) }
    }.returns(Array),

    sort: ->(arr, block=nil) {
      Utils.array_check(arr,'sort')
      if block.nil?
        arr.sort
      else
        arr.sort {|a,b| block.call(a,b) }
      end
    }.returns(Array),

    sort_by: ->(arr, block) {
      Utils.array_check(arr,'sort_by')
      arr = arr.clone
      arr.sort_by! {|e| block.call(e) }
      arr
    }.returns(Array),

    uniq: ->(arr, block=nil) {
      Utils.array_check(arr,'uniq')
      if block.nil?
        arr.uniq
      else
        arr.uniq {|e| block.call(e) }
      end
    }.returns(Array),

    filter: ->(arr,block) {
      Utils.array_check(arr,'filter')
      arr.filter {|element| block.call(element) }
    }.returns(Array),

    map: ->(arr,block) {
      Utils.array_check(arr,'map')
      arr.map {|element| block.call(element) }
    }.returns(Array),

    flat_map: ->(arr,block) {
      Utils.array_check(arr,'flat_map')
      arr.flat_map {|element| block.call(element) }
    }.returns(Array),

    map_with_index: ->(arr,block) {
      Utils.array_check(arr,'map_with_index')
      arr.map.with_index {|element,i| block.call(element,i) }
    }.returns(Array),

    each: ->(arr,block) {
      Utils.array_check(arr,'each')
      arr.each {|element| block.call(element) }
    },

    each_with_index: ->(arr,block) {
      Utils.array_check(arr,'each_with_index')
      arr.each_with_index {|element,idx| block.call(element,idx) }
    },

    each_index: ->(arr,block) {
      Utils.array_check(arr,'each_index')
      arr.each_index {|idx| block.call(idx) }
    },

    foldl: ->(arr,init_val,block) {
      Utils.array_check(arr,'foldl')
      arr.inject(init_val) {|acc,n| block.call(acc,n) }
    }.returns(Object),

    foldr: ->(arr,init_val,block) {
      Utils.array_check(arr,'foldr')
      arr.reverse.inject(init_val) {|acc,n| block.call(acc,n) }
    }.returns(Object),

    grep: ->(arr, pattern_str, block=nil) {
      if block.nil?
        arr.grep(Regexp.new(pattern_str))
      else
        arr.grep(Regexp.new(pattern_str)) {|e| block.call(e) }
      end
    }.returns(Array),

    grep_v: ->(arr, pattern_str, block=nil) {
      if block.nil?
        arr.grep_v(Regexp.new(pattern_str))
      else
        arr.grep_v(Regexp.new(pattern_str)) {|e| block.call(e) }
      end
    }.returns(Array),

    fill: ->(arr, obj, start=nil, count=nil) { arr.fill(obj,start,count) }.returns(Array),
    join: ->(arr, sep='') { Utils.array_check(arr,'join'); arr.join(sep) }.returns(String),
    csv: ->(arr) { Utils.array_check(arr,'csv'); arr.join(',') }.returns(String),
    from_csv: ->(str) { Utils.string_check(str,'from_csv'); str.split(',') }.returns(Array),
    at: ->(arr,i) { Utils.array_check(arr,'at'); arr.at(i) }.returns(Object),
    first: ->(arr) { Utils.array_check(arr,'first'); arr[0] }.returns(Object),
    last: ->(arr) { Utils.array_check(arr,'last'); arr[-1] }.returns(Object),
    max: ->(arr) { Utils.array_check(arr,'max'); arr.max }.returns(Object),
    min: ->(arr) { Utils.array_check(arr,'min'); arr.min }.returns(Object),
    minmax: ->(arr) { Utils.array_check(arr,'minmax'); arr.minmax }.returns(Array),
    sum: ->(arr,init=0) { Utils.array_check(arr,'sum'); arr.sum(init) }.returns(Integer),
    to_c_array: ->(arr) { Utils.to_c_array(arr) }.returns(String),

    max_by: ->(arr, block) {
      Utils.array_check(arr,'max_by')
      arr.max_by {|e| block.call(e) }
    }.returns(Object),

    min_by: ->(arr, block) {
      Utils.array_check(arr,'min_by')
      arr.min_by {|e| block.call(e) }
    }.returns(Object),

    sample: ->(arr, count=nil) {
      Utils.array_check(arr, 'sample')
      count.nil? ? arr.sample : arr.sample(count)
    }.returns(Object).impure
      .describe('Gets a random element of the given array.'),

    year:   -> { Time.now.year }.returns(Integer) .impure.describe('Gets the current year.'),
    month:  -> { Time.now.month }.returns(Integer).impure.describe('Gets the current month.'),
    day:    -> { Time.now.day }.returns(Integer)  .impure.describe('Gets the current day.'),
    hour:   -> { Time.now.hour }.returns(Integer) .impure.describe('Gets the current hour.'),
    minute: -> { Time.now.min }.returns(Integer)  .impure.describe('Gets the current minute.'),
    second: -> { Time.now.sec }.returns(Integer)  .impure.describe('Gets the current second.'),

    rand: ->(n1=nil,n2=nil) {
      if n1.is_a? Array
        if n2.nil? || !n2.is_a?(Integer)
          n1.sample
        else
          n1.sample(n2)
        end
      else
        n1.nil? ? Random.rand() : (n2.nil? ? Random.rand(n1) : Random.rand(n1..n2))
      end
    }.returns(Object).impure,

    sub: ->(n_or_arr,n_or_pattern,replacement='') {
      if n_or_arr.is_a? Numeric
        n_or_arr - n_or_pattern
      else
        n_or_arr.sub(n_or_pattern,replacement)
      end
    }.returns(Object)
      .describe(
        "Subtracts two numbers, or, if an Array is given, replaces the first occurence of the given pattern with the "\
        "given replacement."
    ),

    add: ->(a,b) { a + b }.returns(Object).describe('Adds two objects.'),
    mul: ->(a,b) { a * b }.returns(Numeric).describe('Multiplies two numbers.'),
    div: ->(a,b) { a / b }.returns(Numeric).describe('Divides two numbers.'),
    mod: ->(a,b) { a % b }.returns(Numeric).describe('Gets the modulo of two numbers.'),
    abs: ->(n) { n.abs }.returns(Numeric).describe('Gets the absolute value of the given number.'),
    sin: ->(n) { Math.sin(n) }.returns(Float).describe('Gets the sine of the given number in radians.'),
    cos: ->(n) { Math.cos(n) }.returns(Float).describe('Gets the cosine of the given number in radians.'),
    tan: ->(n) { Math.tan(n) }.returns(Float).describe('Gets the tangent of the given number in radians.'),
    exp: ->(n) { Math.exp(n) }.returns(Float).describe('Gets e raised to the power of the given number.'),
    log: ->(n) { Math.log(n) }.returns(Float).describe('Gets the base logarithm of the given number.'),
    sqrt: ->(n) { Math.sqrt(n) }.returns(Float).describe('Gets the square root of the given number.'),
    round: ->(f, n_digits=0) { f.round(n_digits) }.returns(Numeric),
    clamp: ->(n, min,max=nil) { n.clamp(min,max) }.returns(Numeric)
      .describe('Clamps number between given min and max values.'),

    over:  ->(addr_or_sym,ov=nil) { Utils.gen_hook_str('over', addr_or_sym, ov) }.returns(String)
      .describe(Utils.gen_hook_description('over')),
    hook:  ->(addr_or_sym,ov=nil) { Utils.gen_hook_str('hook', addr_or_sym, ov) }.returns(String)
      .describe(Utils.gen_hook_description('hook')),
    call:  ->(addr_or_sym,ov=nil) { Utils.gen_hook_str('call', addr_or_sym, ov) }.returns(String)
      .describe(Utils.gen_hook_description('call')),
    jump:  ->(addr_or_sym,ov=nil) { Utils.gen_hook_str('jump', addr_or_sym, ov) }.returns(String)
      .describe(Utils.gen_hook_description('jump')),
    thook: ->(addr_or_sym,ov=nil) { Utils.gen_hook_str('thook', addr_or_sym, ov) }.returns(String)
      .describe(Utils.gen_hook_description('thook')),
    tcall: ->(addr_or_sym,ov=nil) { Utils.gen_hook_str('tcall', addr_or_sym, ov) }.returns(String)
      .describe(Utils.gen_hook_description('tcall')),
    tjump: ->(addr_or_sym,ov=nil) { Utils.gen_hook_str('tjump', addr_or_sym, ov) }.returns(String)
      .describe(Utils.gen_hook_description('tjump')),

    set_hook:  ->(addr,ov,fn=nil) { Utils.gen_set_hook_str('set_hook', addr, ov, fn) }
      .returns(String).ignore_unk_var_at_arg(1,2),

    set_call:  ->(addr,ov,fn=nil) { Utils.gen_set_hook_str('set_call', addr, ov, fn) }
      .returns(String).ignore_unk_var_at_arg(1,2),

    set_jump:  ->(addr,ov,fn=nil) { Utils.gen_set_hook_str('set_jump', addr, ov, fn) }
      .returns(String).ignore_unk_var_at_arg(1,2),

    set_thook: ->(addr,ov,fn=nil) { Utils.gen_set_hook_str('set_thook', addr, ov, fn) }
      .returns(String).ignore_unk_var_at_arg(1,2),

    set_tcall: ->(addr,ov,fn=nil) { Utils.gen_set_hook_str('set_tcall', addr, ov, fn) }
      .returns(String).ignore_unk_var_at_arg(1,2),

    set_tjump: ->(addr,ov,fn=nil) { Utils.gen_set_hook_str('set_tjump', addr, ov, fn) }
      .returns(String).ignore_unk_var_at_arg(1,2),

    repl: ->(addr, ov_or_asm, asm=nil) {
      Utils.gen_hook_str('repl', addr, ov_or_asm.is_a?(String) ? nil : ov_or_asm, asm.nil? ? ov_or_asm : asm)
    }.returns(String),

    trepl: ->(addr, ov_or_asm, asm=nil) {
      'ncp_thumb ' +
        Utils.gen_hook_str('repl', addr, ov_or_asm.is_a?(String) ? nil : ov_or_asm, asm.nil? ? ov_or_asm : asm)
    }.returns(String),

    over_guard: ->(loc,ov=nil) { Utils.gen_c_over_guard(loc, ov) }.returns(String),

    over_func: ->(loc,ov=nil) {
      addr, ov = Utils.resolve_loc(loc,ov)
      Utils.gen_c_over_guard(addr + Utils.get_function_size(addr,ov),ov) + "\n\n" + Utils.gen_hook_str('over', addr,ov)
    }.returns(String),

    repl_imm: ->(loc, ov, val) { Utils.modify_ins_immediate(loc, ov, val) }.returns(String)
      .describe("Modifies the immediate in the instruction at the given address by generating a 'repl' hook using " \
                "the original ASM with the immediate swapped to the value given."),

    repl_array: ->(loc, ov, dtype, arr) { Utils.gen_repl_array(loc,ov,dtype,arr) }.returns(String),

    repl_u64_array: ->(loc,ov_or_arr,arr=nil) { Utils.gen_repl_type_array(loc, ov_or_arr, :u64, arr) }.returns(String),
    repl_s64_array: ->(loc,ov_or_arr,arr=nil) { Utils.gen_repl_type_array(loc, ov_or_arr, :s64, arr) }.returns(String),
    repl_u32_array: ->(loc,ov_or_arr,arr=nil) { Utils.gen_repl_type_array(loc, ov_or_arr, :u32, arr) }.returns(String),
    repl_s32_array: ->(loc,ov_or_arr,arr=nil) { Utils.gen_repl_type_array(loc, ov_or_arr, :s32, arr) }.returns(String),
    repl_u16_array: ->(loc,ov_or_arr,arr=nil) { Utils.gen_repl_type_array(loc, ov_or_arr, :u16, arr) }.returns(String),
    repl_s16_array: ->(loc,ov_or_arr,arr=nil) { Utils.gen_repl_type_array(loc, ov_or_arr, :s16, arr) }.returns(String),
    repl_u8_array: ->(loc,ov_or_arr,arr=nil) { Utils.gen_repl_type_array(loc, ov_or_arr, :u8, arr) }.returns(String),
    repl_s8_array: ->(loc,ov_or_arr,arr=nil) { Utils.gen_repl_type_array(loc, ov_or_arr, :s8, arr) }.returns(String),

    hex_edit: ->(ov, og_hex_str, new_hex_str) { Utils.gen_hex_edit(ov, og_hex_str, new_hex_str) }.returns(String),

    code_loc: ->(loc,ov=nil) { CodeLoc.new(loc, ov) }.returns(CodeLoc), # Will this ever be properly implemented? TBD
    next_addr: ->(current_addr,ov=nil) { Utils.next_addr(current_addr,ov) }.returns(Integer),
    addr_to_sym: ->(addr,ov=nil) { Utils.addr_to_sym(addr, ov) }.returns(String),
    sym_to_addr: ->(sym) { Utils.sym_to_addr(sym) }.returns(Integer),
    get_sym_ov: ->(sym) { Utils.get_sym_ov(sym) }.returns(Integer),
    sym_from_index: ->(idx) { Unarm.sym_map.to_a[idx][0] }.returns(String),
    demangle: ->(sym) { Unarm.shitty_demangle(sym) }.returns(String),

    get_function: ->(addr,ov=nil) { Utils.get_reloc_func(addr, ov) }.returns(String),
    get_instruction: ->(addr,ov=nil) { Utils.get_instruction(addr, ov) }.returns(String),
    get_reloc_instruction: ->(addr,ov=nil) { Utils.get_raw_instruction(addr, ov).str }.returns(String),
    get_dword: ->(addr,ov=nil) { Utils.get_dword(addr,ov) }.returns(Integer),
    get_word:  ->(addr,ov=nil) { Utils.get_word(addr,ov) }.returns(Integer),
    get_hword: ->(addr,ov=nil) { Utils.get_hword(addr,ov) }.returns(Integer),
    get_byte:  ->(addr,ov=nil) { Utils.get_byte(addr,ov) }.returns(Integer),
    get_signed_dword: ->(addr,ov=nil) { Utils.get_signed_dword(addr,ov) }.returns(Integer),
    get_signed_word:  ->(addr,ov=nil) { Utils.get_signed_word(addr,ov) }.returns(Integer),
    get_signed_hword: ->(addr,ov=nil) { Utils.get_signed_hword(addr,ov) }.returns(Integer),
    get_signed_byte:  ->(addr,ov=nil) { Utils.get_signed_byte(addr,ov) }.returns(Integer),
    get_cstring: ->(addr,ov=nil) { Utils.get_cstring(addr,ov) }.returns(String),
    get_array: ->(addr,ov,e_type_id,e_count=1) { Utils.get_array(addr,ov,e_type_id,e_count) }.returns(Array),
    get_chars: ->(addr,ov, char_count) { Utils.get_array(addr,ov,Utils::DTYPE_IDS[:u8],char_count).map { it.chr } }
      .returns(Array),

    get_c_array: ->(addr,ov,e_type_id,e_count=1) {
      Utils.to_c_array(Utils.get_array(addr,ov,e_type_id,e_count))
    }.returns(Array),

    get_byte_str: ->(loc,ov,size) { Utils.get_byte_str(loc,ov,size) }.returns(String),

    find_first_branch_to: ->(branch_dest, start_loc,start_ov=nil) {
      Utils.find_branch_to(branch_dest, start_loc,start_ov)
    }.returns(Integer),

    find_first_branch_to_in_func: ->(branch_dest, func_loc,func_ov=nil) {
      Utils.find_branch_to(branch_dest, func_loc,func_ov, from_func: true)
    }.returns(Integer),

    in_func_find_first_branch_to: ->(func_loc,func_ov, branch_dest) {
      Utils.find_branch_to(branch_dest, func_loc,func_ov, from_func: true)
    }.returns(Integer),

    find_branches_to_in_func: ->(branch_dest, func_loc,func_ov=nil) {
      Utils.find_branch_to(branch_dest, func_loc,func_ov, from_func: true, find_all: true)
    }.returns(Array),

    in_func_find_branches_to: ->(func_loc,func_ov, branch_dest) {
      Utils.find_branch_to(branch_dest, func_loc,func_ov, from_func: true, find_all: true)
    }.returns(Array),

    track_reg: ->(reg, from_addr,ov, to_addr) { Utils.track_reg(reg, from_addr,ov, to_addr) }.returns(String),

    find_ins_in_func: ->(ins_pattern_str, func_loc,func_ov=nil) {
      Utils.find_ins_in_func(ins_pattern_str,func_loc,func_ov)
    }.returns(Integer),

    get_ins_mnemonic: ->(loc,ov=nil) { Utils.get_ins_mnemonic(loc,ov) }.returns(String),
    get_ins_arg: ->(loc,ov,arg_index) { Utils.get_ins_arg(loc,ov,arg_index) }.returns(String),
    get_ins_branch_dest: ->(loc,ov=nil) { Utils.get_ins_branch_dest(loc,ov) }.returns(Integer),
    get_ins_target_addr: ->(loc,ov=nil) { Utils.get_ins_target_addr(loc,ov) }.returns(Integer),

    get_function_literal_pool: ->(loc,ov=nil) { Utils.get_func_literal_pool(loc,ov) }.returns(String)
      .describe('Gets the literal pool of the given function as a String of ASM.'),

    get_function_literal_pool_values: ->(loc,ov=nil) {
      Utils.get_func_literal_pool_values(loc,ov)
    }.returns(Array)
      .describe('Gets the literal pool values of the given function as an Array of integers.'),

    get_function_literal_pool_addresses: ->(loc,ov=nil) {
      Utils.get_func_literal_pool_addrs(loc,ov)
    }.returns(Array)
      .describe('Gets an Array containing the addresses of each literal pool entry of the given function.'),

    get_function_size: ->(loc,ov=nil) { Utils.get_function_size(loc,ov) }.returns(Integer)
      .describe('Gets the size of the function at the given location. Includes the literal pool.'),

    disasm_arm_ins: ->(data) { Utils.disasm_arm_ins(data) }.returns(String),
    disasm_thumb_ins: ->(data) { Utils.disasm_thumb_ins(data) }.returns(String),

    disasm_arm_hex_seq: ->(hex_byte_str) { Utils.disasm_hex_seq(hex_byte_str) }.returns(Array),
    disasm_thumb_hex_seq: ->(hex_byte_str) { Utils.disasm_hex_seq(hex_byte_str) }.returns(Array),

    is_address_in_overlay: ->(addr, ov) { Utils.addr_in_overlay?(addr, ov) }.returns(Object)
      .describe('Gets whether the given address is in the given overlay.'),

    is_address_in_arm9: ->(addr) { Utils.addr_in_arm9?(addr) }.returns(Object)
      .describe('Gets whether the given address is in ARM9.'),

    is_address_in_arm7: ->(addr) { Utils.addr_in_arm7?(addr) }.returns(Object)
      .describe('Gets whether the given address is in ARM7.'),

    find_hex_bytes: ->(ov, hex_str) { Utils.find_hex_bytes(ov,hex_str) }.returns(Integer),

    fx64: ->(n) { (n * (1 << 12)).round().signed(64) }.returns(Integer)
      .describe('Gets the given number as an fx64 (an s51.12 fixed point number).'),

    from_fx64: ->(n) { n.signed(64) / Float(1 << 12) }.returns(Float)
      .describe('Gets the given fx64 number as a Float.'),

    fx32: ->(n) { (n * (1 << 12)).round().signed(32) }.returns(Integer)
      .describe('Gets the given number as an fx32 (an s19.12 fixed point number).'),

    from_fx32: ->(n) { n.signed(32) / Float(1 << 12) }.returns(Float)
      .describe('Gets the given fx32 number as a Float.'),

    fx16: ->(n) { (n * (1 << 12)).round().signed(16) }.returns(Integer)
      .describe('Gets the given number as an fx16 (an s3.12 fixed point number).'),

    from_fx16: ->(n) { n.signed(16) / Float(1 << 12) }.returns(Float)
      .describe('Gets the given fx16 number as a Float.'),

    u64: ->(n) { n.unsigned(64) }.returns(Integer).describe('Gets the given number as an unsigned 64-bit Integer.'),
    s64: ->(n) { n.signed(64)   }.returns(Integer).describe('Gets the given number as a signed 64-bit Integer.'),
    u32: ->(n) { n.unsigned(32) }.returns(Integer).describe('Gets the given number as an unsigned 32-bit Integer.'),
    s32: ->(n) { n.signed(32)   }.returns(Integer).describe('Gets the given number as a signed 32-bit Integer.'),
    u16: ->(n) { n.unsigned(16) }.returns(Integer).describe('Gets the given number as an unsigned 16-bit Integer.'),
    s16: ->(n) { n.signed(16)   }.returns(Integer).describe('Gets the given number as a signed 16-bit Integer.'),
    u8: ->(n)  { n.unsigned(8)  }.returns(Integer).describe('Gets the given number as an unsigned 8-bit Integer.'),
    s8: ->(n)  { n.signed(8)    }.returns(Integer).describe('Gets the given number as a signed 8-bit Integer.'),
    char: ->(n) { n.unsigned(8).chr }.returns(String).describe('Gets the given number as an ASCII character.'),

    sizeof: ->(dtype) { Utils::DTYPES[dtype][:size] }.returns(Integer),

    f32: ->(n) { [n].pack('g').unpack('L>') }.returns(Integer),
    f64: ->(n) { [n].pack('G').unpack('Q>') }.returns(Integer),
    from_f32: ->(n) { [n].pack('L>').unpack('g')[0] }.returns(Float),
    from_f64: ->(n) { [n].pack('Q>').unpack('G')[0] }.returns(Float),

    from_fx_deg: ->(fx_num) {
      Float(fx_num) / 0x10000 * 360
    }.returns(Float),

    fx_deg: ->(n) {
      if n < 0
        n -= 360 while n >= 360
      else
        n += 360 while n < 0
      end
      (n * 0x10000 / 360).signed(16)
    }.returns(Integer),

    gx_rgb: ->(r,g,b) { ((r << 0) | (g << 5) | (b << 10)).unsigned(16) }.returns(Integer)
      .describe('Packs the given values into an RGB x1B5G5R5 format 16-bit unsigned integer.'),
    gx_rgba: ->(r,g,b,a) { ((r << 0) | (g << 5) | (b << 10) | (a << 15)).unsigned(16) }.returns(Integer)
      .describe('Packs the given values into an RGB A1B5G5R5 format 16-bit unsigned integer.'),

    from_gx_rgb: ->(n) { [(n >> 0) & 31, (n >> 5) & 31, (n >> 10) & 31] }.returns(Array)
      .describe('Unpacks the given RGB x1B5G5R5 value as an Array ([R,G,B]).'),
    from_gx_rgba: ->(n) { [(n >> 0) & 31, (n >> 5) & 31, (n >> 10) & 31, (n >> 15) & 1] }.returns(Array)
      .describe('Unpacks the given packed RGB A1B5G5R5 value as an Array ([R,G,B,A]).'),

    pack_u64_array: ->(arr) { arr.pack('Q*') }.returns(String),
    pack_u32_array: ->(arr) { arr.pack('L*') }.returns(String),
    pack_u16_array: ->(arr) { arr.pack('S*') }.returns(String),
    pack_u8_array: ->(arr) { arr.pack('C*') }.returns(String),
    pack_s64_array: ->(arr) { arr.pack('q*') }.returns(String),
    pack_s32_array: ->(arr) { arr.pack('l*') }.returns(String),
    pack_s16_array: ->(arr) { arr.pack('s*') }.returns(String),
    pack_s8_array: ->(arr) { arr.pack('c*') }.returns(String),

    unpack_u64_array: ->(byte_str) { byte_str.unpack('Q*') }.returns(Array),
    unpack_u32_array: ->(byte_str) { byte_str.unpack('L*') }.returns(Array),
    unpack_u16_array: ->(byte_str) { byte_str.unpack('S*') }.returns(Array),
    unpack_u8_array: ->(byte_str) { byte_str.unpack('C*') }.returns(Array),
    unpack_s64_array: ->(byte_str) { byte_str.unpack('q*') }.returns(Array),
    unpack_s32_array: ->(byte_str) { byte_str.unpack('l*') }.returns(Array),
    unpack_s16_array: ->(byte_str) { byte_str.unpack('s*') }.returns(Array),
    unpack_s8_array: ->(byte_str) { byte_str.unpack('c*') }.returns(Array),

    emulate_func: ->(loc,ov,*args) { Utils.emulate_func(loc,ov,*args) }.returns(Object).impure,
    emu_get_reg: ->(reg_s) { $emu.read_reg(reg_s.to_sym) }.returns(Integer).impure,
    emu_set_reg: ->(reg_s,val) { $emu.write_reg(reg_s.to_sym,val) }.impure,
    emu_get_mem: ->(loc,size) { Utils.emu_get_mem(loc,size) }.returns(String).impure,
    emu_set_mem: ->(loc,byte_str) { Utils.emu_set_mem(loc,byte_str) }.impure,
    emu_load_ov: ->(ov_id) { $emu.load_overlay(ov_id) }.impure,
    emu_reset: -> { $emu = Uc::Emu.new(); $emu.load_arm9 }.impure,

    assemble_arm: ->(asm,addr=0) { Utils.assemble_arm(asm,addr:addr) }.returns(Integer),
    assemble_thumb: ->(asm,addr=0) { Utils.assemble_thumb(asm,addr:addr) }.returns(Integer),

  },

  aliases: {
    snuff:         :null,
    discard:       :null,
    _:             :place,
    try_or_msg:    :try_or_message,
    tramp:         :trampoline,
    eql:           :equal,
    equals:        :equal,
    size:          :length,
    str:           :string,
    integer:       :int,
    upper:         :upcase,
    lower:         :downcase,
    capitalise:    :capitalize,
    quoted:        :str_literal,
    del:           :delete,
    to_hex:        :hex,
    is_null:       :is_nil,
    len:           :length,
    contains:      :includes,
    map_with_idx:  :map_with_index,
    each_with_idx: :each_with_index,
    each_idx:      :each_index,
    find_all:      :filter,
    reduce:        :foldr,
    inject:        :foldr,
    random:        :rand,
    get_func:      :get_function,
    get_ins:       :get_instruction,
    get_reloc_ins: :get_reloc_instruction,
    get_u64:       :get_dword,
    get_s64:       :get_signed_dword,
    get_u32:       :get_word,
    get_s32:       :get_word,
    get_int:       :get_word,
    get_u16:       :get_hword,
    get_s16:       :get_signed_hword,
    get_u8:        :get_byte,
    get_s8:        :get_signed_byte,
    get_cstr:      :get_cstring,
    disasm_ins:    :disasm_arm_ins,
    disasm:        :disasm_arm_ins,
    disasm_hex_seq: :disasm_arm_hex_seq,
    disasm_hex_str: :disasm_arm_hex_seq,
    disasm_arm_hex_str: :disasm_arm_hex_seq,
    disasm_thumb_hex_str: :disasm_thumb_hex_seq,
    sym_to_ov:     :get_sym_ov,
    get_address:   :sym_to_addr,
    get_addr:      :sym_to_addr,
    get_symbol:    :addr_to_sym,
    get_sym:       :addr_to_sym,
    get_arr:       :get_array,
    to_c_arr:      :to_c_array,
    mod_imm:       :repl_imm,
    repl_arr:      :repl_array,
    repl_fx32_arr: :repl_s32_array,
    repl_fx16_arr: :repl_s16_array,
    repl_u64_arr:  :repl_u64_array,
    repl_s64_arr:  :repl_s64_array,
    repl_u32_arr:  :repl_u32_array,
    repl_s32_arr:  :repl_s32_array,
    repl_u16_arr:  :repl_u16_array,
    repl_s16_arr:  :repl_s16_array,
    repl_u8_arr:   :repl_u8_array,
    repl_s8_arr:   :repl_s8_array,
    repl_fx32_array: :repl_s32_array,
    repl_fx16_array: :repl_s16_array,
    get_func_literal_pool:        :get_function_literal_pool,
    get_func_lit_pool:            :get_function_literal_pool,
    get_func_literal_pool_values: :get_function_literal_pool_values,
    get_func_lit_pool_vals:       :get_function_literal_pool_values,
    get_func_literal_pool_addrs:  :get_function_literal_pool_addresses,
    get_func_lit_pool_addrs:      :get_function_literal_pool_addresses,
    get_func_size:                :get_function_size,
    get_ins_load_addr:            :get_ins_target_addr,
    is_addr_in_overlay:           :is_address_in_overlay,
    is_addr_in_ov:                :is_address_in_overlay,
    is_addr_in_arm9:              :is_address_in_arm9,
    is_addr_in_arm7:              :is_address_in_arm7,
    find_hex_seq:                 :find_hex_bytes,
    pack_u64_arr:                 :pack_u64_array,
    pack_u32_arr:                 :pack_u32_array,
    pack_u16_arr:                 :pack_u16_array,
    pack_u8_arr:                  :pack_u8_array,
    pack_s64_arr:                 :pack_s64_array,
    pack_s32_arr:                 :pack_s32_array,
    pack_s16_arr:                 :pack_s16_array,
    pack_s8_arr:                  :pack_s8_array,
    unpack_u64_arr:               :unpack_u64_array,
    unpack_u32_arr:               :unpack_u32_array,
    unpack_u16_arr:               :unpack_u16_array,
    unpack_u8_arr:                :unpack_u8_array,
    unpack_s64_arr:               :unpack_s64_array,
    unpack_s32_arr:               :unpack_s32_array,
    unpack_s16_arr:               :unpack_s16_array,
    unpack_s8_arr:                :unpack_s8_array,
    emulate_function:             :emulate_func,
    emu_call_func:                :emulate_func,
    emu_get_register:             :emu_get_reg,
    emu_set_register:             :emu_set_reg,
    emu_get_memory:               :emu_get_mem,
    emu_set_memory:               :emu_set_mem,
    emu_load_overlay:             :emu_load_ov,
    assemble:                     :assemble_arm,
    assemble_ins:                 :assemble_arm,
    assemble_arm_ins:             :assemble_arm,
    assemble_thumb_ins:           :assemble_thumb
  }).freeze


  CORE_VARIABLES = {
    NCPP_VERSION: VERSION,
    BUILD_DATE: Time.now.to_s,
    PI: Math::PI,
    EOL: "\n",
    TAB: "\t",
    u64:  Utils::DTYPE_IDS[:u64],
    u32:  Utils::DTYPE_IDS[:u32],
    u16:  Utils::DTYPE_IDS[:u16],
    u8:   Utils::DTYPE_IDS[:u8],
    s64:  Utils::DTYPE_IDS[:s64],
    s32:  Utils::DTYPE_IDS[:s32],
    fx32: Utils::DTYPE_IDS[:s32],
    s16:  Utils::DTYPE_IDS[:s16],
    fx16: Utils::DTYPE_IDS[:s16],
    s8:   Utils::DTYPE_IDS[:s8],
    ARM9: -1,
    ARM7: -2
  }.freeze

end
