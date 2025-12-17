require_relative 'parser.rb'
require_relative 'commands.rb'

require 'fileutils'

module NCPP

  #
  # NCPP language interpreter
  #
  class Interpreter
    # Interpreter environment-specific commands
    def commands
      CommandRegistry.new({
        put: ->(x, on_new_line=true) {
          if on_new_line
            @out_stack << x.to_s
          else
            @out_stack[-1] << x.to_s
          end
        }.impure
          .describe(
          "Puts the value of the given argument as a String on the end of the out-stack; but if 'on_new_line' is true "\
          "(it's false by default), it's added to the end of the last stack entry."
        ),

        get_out_stack: -> { @out_stack }.returns(Array).impure
          .describe('Gets the out-stack.'),

        clear_out_stack: -> { @out_stack.clear }.impure
          .describe('Clears the out-stack.'),

        ruby: ->(code_str) {
          raise "The 'ruby' command can't be run in safe mode" if @safe_mode
          eval(code_str, get_binding)
        }.returns(Object).impure
          .describe('Evaluates the given String as Ruby code.'),

        eval: ->(expr_str) { eval_str(expr_str) }.returns(Object).impure
          .describe('Evaluates the given String as an NCPP expression.'),

        do_command: ->(cmd_str, *args) { call(cmd_str,get_command(cmd_str),*args) }.returns(Object)
          .describe('Calls the command named in the given String.'),

        map_to_command: ->(arr, cmd_str, *args) {
          Utils.array_check(arr,'map_to_command')
          cmd = get_command(cmd_str)
          arr.map {|element| args.nil? ? call(cmd_str,cmd,element) : call(cmd_str,cmd,element,*args) }
        }.returns(Array)
          .describe('Calls the command named in the String given on each element in the provided Array.'),

        inject_in_command: ->(arr, init_val, cmd_str) {
          Utils.array_check(arr, 'inject_in_command')
          cmd = get_command(cmd_str)
          arr.inject(init_val) {|acc,n| call(cmd_str,cmd,acc,n) }
        }.returns(Object),

        define_command: ->(name, block) { def_command(name, block) }
          .describe('Defines a command with the name given and a Block or a Ruby Proc.'),

        alias_command: ->(new_name, name) {
          Utils.valid_identifier_check(name)
          raise "Alias name '#{new_name}' is occupied" if @commands.has_key?(new_name.to_sym)
          @commands[new_name.to_sym] = @commands[name.to_sym]
        }.describe('Adds an alias for an existing command.'),

        define_variable: ->(var_name, val = nil) { def_variable(var_name, val) }
          .describe('Defines a variable with the name and value given. If no value is given, it is set to nil.'),

        define: ->(name, val = nil) {
          if val.is_a?(Block) || val.is_a?(Proc)
            def_command(name, val)
          else
            def_variable(name, val)
          end
        }.describe(
          "Defines a variable or command with the name and value given. A command is defined if the value is a Block "\
          "or a Ruby Proc, otherwise it is a variable."
        ),

        delete_variable: ->(var_str, panic_if_missing = true) {
          unknown_variable_error(var_str) if panic_if_missing && !@variables.has_key?(var_str.to_sym)
          @variables.delete(var_str.to_sym)
        }.impure
         .describe('Deletes the variable corresponding to the given name.'),

        describe: ->(cmd_str) {
          cmd = @commands[cmd_str.to_sym]
          unknown_command_error(cmd_str) if cmd.nil?
          out = ''
          if cmd.is_a?(Proc)
            out << (cmd.description or '')
            params = cmd.parameters.map {|type,arg| "#{arg} (#{type})" }
            out << "#{"\n" if !out.empty?}Param#{'s' if params.length != 1}: #{params.join(', ')}" unless params.empty?
            out << "#{"\n" if !out.empty?}Returns: #{cmd.return_type}" unless cmd.return_type.nil?
            unless cmd.pure? && cmd.ignore_unk_var_args.empty?
              out << "#{"\n" if !out.empty?}Notes:\n"
              out << "* Impure" unless cmd.pure?
              unless cmd.ignore_unk_var_args.empty?
                out << "* Unknown variables ignored at args #{cmd.ignore_unk_var_args.join(', ')}"
              end
            end
          elsif !cmd.pure?
            out << "Notes:\n* Impure"
          end
          aliases = @commands.select {|k,v| k.to_s != cmd_str && v == cmd }.keys
          out << "#{"\n" if !out.empty?}Alias#{'es' if aliases.length != 1}: #{aliases.join(', ')}" if !aliases.empty?
          out
        }.returns(String)
          .describe(
            'Describes a given command if a description is present and lists its parameters, return type, and aliases.'
        ),

        get_command_names: -> { @commands.keys.map { it.to_s } }
          .returns(Array)
          .describe('Gets an array containing each command name.'),

        get_variable_names: -> { @variables.keys.map { it.to_s } }
          .returns(Array)
          .describe('Gets an array containing each variables name.'),

        benchmark: ->(block_or_cmd, repeats, *args) {
          thing = block_or_cmd.is_a?(String) ? get_command(block_or_cmd) : block_or_cmd
          start_time = Time.now
          if args.nil?
            repeats.times { thing.call }
          else
            repeats.times { thing.call(*args) }
          end
          Time.now - start_time
        }.returns(Float).impure
          .describe('Times how long it takes to do the given Block or Command the amount of times given.'),

        is_pure: ->(block_proc_or_cmd) {
          if block_proc_or_cmd.is_a? String
            get_command(block_proc_or_cmd).pure?
          else
            block_proc_or_cmd.pure?
          end
        }.returns(Object)
          .describe('Gets whether the given Block, Ruby Proc, or command is pure.'),

        vow_purity: -> { @puritan_mode = true }.impure
          .describe('Activates puritan mode, disallowing the use of impure commands.'),
        vow_safety: -> { @safe_mode = true }.impure
          .describe('Activates safe mode, disallowing the use of inline Ruby commands.'),
        break_purity_vow: -> { @puritan_mode = false } # impure
          .describe('Deactivates puritan mode, allowing the use of impure commands.'),
        break_safety_vow: -> { @safe_mode = false }.impure
          .describe('Deactivates puritan mode, allpwing the use of impure commands.'),
        break_vows: -> { @puritan_mode = false; @safe_mode = false } # impure
          .describe('Breaks all vows.'),

        invalidate_cache: -> { @command_cache&.clear }.impure
          .describe('Clears command cache.')
      },

      aliases: {
        out:           :put,
        do_cmd:        :do_command,
        map_to_cmd:    :map_to_command,
        inject_in_cmd: :inject_in_command,
        define_cmd:    :define_command,
        def_cmd:       :define_command,
        alias_cmd:     :alias_command,
        def_var:       :define_variable,
        set_var:       :define_variable,
        delete_var:    :delete_variable,
        del_var:       :delete_variable,
        def:           :define,
        desc:          :describe,
        get_cmd_names: :get_command_names,
        get_var_names: :get_variable_names,
        clear_cache:   :invalidate_cache
      }).freeze
    end

    def variables
      {
        SYMBOL_COUNT: Unarm.symbols.count,
        SYMBOL_NAMES: Unarm.symbols.map.keys, # TODO: how should I handle ARM7 ??
        DEMANGLED_SYMBOL_NAMES: Unarm.symbols.demangled_map.keys,
        OVERLAY_COUNT: $rom.overlay_count,
        GAME_TITLE: $rom.header.game_title,
        NITRO_SDK_VERSION: $rom.nitro_sdk_version
        # OVERLAY_OFFSETS: Array.new($rom.overlay_count, 0)
      }
    end

    def initialize(cmd_prefix = COMMAND_PREFIX, extra_cmds = {}, extra_vars = {}, safe: false, puritan: false, 
                   no_cache: false, cmd_cache: {})

      @parser = Parser.new(cmd_prefix: cmd_prefix)
      @transformer = Transformer.new

      @COMMAND_PREFIX = cmd_prefix

      @safe_mode = safe
      @puritan_mode = puritan

      @commands = commands.merge(CORE_COMMANDS).merge(extra_cmds)

      @variables = {}
      @variables.merge!(variables) unless $rom.nil?
      @variables.merge!(CORE_VARIABLES).merge!(extra_vars)

      @added_commands = extra_cmds.keys.to_set
      @added_variables = extra_vars.keys.to_set

      @out_stack = []
      @command_cache = no_cache ? nil : cmd_cache
    end

    def get_binding
      binding
    end

    def get_new_commands
      @added_commands.to_h {|cmd| [cmd, @commands[cmd]] }
    end

    def get_new_variables
      @added_variables.to_h {|var| [var, @variables[var]] }
    end

    # get cached commands that can be saved
    def get_cacheable_cache
      @command_cache.delete_if {|k,v| @added_commands.include?(k.to_sym) }
    end

    def unknown_command_error(cmd_name)
      alt = @commands.suggest_similar_key(cmd_name)
      raise "Unknown command '#{cmd_name}'#{"\nDid you mean '#{alt}'?" unless alt.nil?}"
    end

    def unknown_variable_error(var_name)
      alt = @variables.suggest_similar_key(var_name)
      raise "Unknown variable '#{var_name}'#{"\nDid you mean '#{alt}'?" unless alt.nil?}"
    end

    def def_command(cmd_name, block)
      Utils.valid_identifier_check(cmd_name)
      raise 'commands must be either Blocks or Ruby Procs' unless block.is_a?(Block) || block.is_a?(Proc)
      cmd_sym = cmd_name.to_sym
      redef = @commands.has_key?(cmd_sym)
      raise 'Redefining commands is not allowed in puritan mode' if @puritan_mode && redef
      @command_cache.clear if !@command_cache.nil? && redef # command cache must be cleared if any command is redefined
      block.name = cmd_name if block.is_a? Block
      @commands[cmd_sym] = block
      @added_commands.add(cmd_sym)
    end

    def get_command(cmd_name)
      cmd = @commands[cmd_name.to_sym]
      unknown_command_error(cmd_name) if cmd.nil?
      cmd
    end

    def call(cmd_name, block_or_proc, *args)
      if !block_or_proc.return_type.nil? && !@command_cache.nil? && block_or_proc.pure?
        return @command_cache[cmd_name][args] if @command_cache.has_key?(cmd_name) && @command_cache[cmd_name].has_key?(args)
        result = block_or_proc.call(*args)
        @command_cache[cmd_name] ||= {}
        @command_cache[cmd_name][args] = result
        result
      else
        block_or_proc.call(*args)
      end
    end

    def def_variable(var_name, val)
      Utils.valid_identifier_check(var_name)
      var_sym = var_name.to_sym
      redef = @variables.has_key?(var_sym)
      raise 'Redefining variables is not allowed in puritan mode' if @puritan_mode && redef
      @command_cache.clear if !@command_cache.nil? && redef # command cache must be cleared if any variable is redefined
      @variables[var_sym] = val
      @added_variables.add(var_sym)
    end

    def get_variable(var_name)
      unknown_variable_error(var_name) unless @variables.has_key?(var_name.to_sym)
      var = @variables[var_name.to_sym]
      var
    end

    # Parses the given String of NCPP code, transforms it, then evaluates resulting AST
    def eval_str(expr_str)
      return nil if expr_str.empty?
      parsed_tree = @parser.parse(expr_str, root: :expression)
      ast = @transformer.apply(parsed_tree)
      eval_expr(ast)
    end

    # Evaluates the given AST
    def eval_expr(node, subs = nil)
      case node
      when Numeric, String, Array, TrueClass, FalseClass, NilClass
        node

      when Hash
        if node[:infix] # binary operation
          lhs = eval_expr(node[:lhs], subs)
          rhs = eval_expr(node[:rhs], subs)
          op = node[:op]
          if op == '&&'
            lhs && rhs
          elsif op == '||'
            lhs || rhs
          else
            lhs.send(op, rhs)
          end

        elsif node[:cond] # ternary operation
          eval_expr(node[:cond], subs) ? eval_expr(node[:e1], subs) : eval_expr(node[:e2], subs)

        elsif node[:op] # unary operation
          op = node[:op]
          # if node[]
          eval_expr(node[:e], subs).send(op == '-' || op == '+' ? op+'@' : op)

        elsif node[:cmd_name] # normal command call
          cmd_name = node[:cmd_name].to_s
          cmd = get_command(cmd_name)
          raise "Cannot use impure command '#{cmd_name}' in puritan mode." if @puritan_mode && !cmd.pure?
          args = Array(node[:args]).map.with_index do |a,i|
            if cmd.is_a?(Proc) && cmd.ignore_unk_var_args.include?(i) &&
                a[:base].is_a?(Hash) && a[:base][:var_name] && !@variables.include?(a[:base][:var_name].to_sym)
              a[:base][:var_name].to_s
            else
              eval_expr(a, subs)
            end
          end
          ret = call(cmd_name,cmd,*args)
          cmd.return_type.nil? ? nil : (node[:subscript_idx].nil? ? ret : ret[eval_expr(node[:subscript_idx], subs)])

        elsif node[:base] && node[:chain] # chained command call
          acc = eval_expr(node[:base], subs)
          no_ret = false
          node[:chain].each do |link|
            next_cmd = link[:next]
            cmd_name = next_cmd[:cmd_name].to_s
            cmd = get_command(cmd_name)
            raise "Cannot use impure command '#{cmd_name}' in puritan mode." if @puritan_mode && !cmd.pure?
            args = Array(next_cmd[:args]).map.with_index do |a,i|
              if !cmd.is_a?(Block) && cmd.ignore_unk_var_args.include?(i) &&
                  a[:base].is_a?(Hash) && a[:base][:var_name] && !@variables.include?(a[:base][:var_name].to_sym)
                a[:base][:var_name].to_s
              else
                eval_expr(a, subs)
              end
            end
            acc = call(cmd_name,cmd, acc,*args)
            no_ret = cmd.return_type.nil?
          end
          no_ret ? nil : acc

        elsif node[:var_name]
          unless subs.nil?
            var_name = node[:var_name].to_s
            if subs.has_key?(var_name)
              ret = subs[var_name]
              return (node[:subscript_idx].nil? ? ret : ret[eval_expr(node[:subscript_idx], subs)])
            end
          end
          var_name = node[:var_name].to_s
          ret = get_variable(var_name)
          node[:subscript_idx].nil? ? ret : ret[eval_expr(node[:subscript_idx], subs)]

        elsif node[:block]
          Block.new(node[:block], node[:args], self, subs)

        elsif node[:array]
          arr = Array(node[:array]).map { |a| eval_expr(a, subs) }
          if node[:subscript_idx].nil?
            arr
          else
            arr[eval_expr(node[:subscript_idx], subs)]
          end

        elsif node[:string]
          node[:string].to_s[eval_expr(node[:subscript_idx], subs)]

        elsif node[:bool]
          node[:bool].to_s == 'true' ? true : false

        elsif node[:nil]
          nil

        else
          raise "Unknown node type: #{node.inspect}"
        end

      else
        raise "Unexpected node: #{node.inspect}"
      end
    end

    # AST purity checking - if a call to an impure command or Block is found, return true
    def node_impure?(node, self_name = nil)
      case node
      when Numeric, String, Array, TrueClass, FalseClass, NilClass
        return false

      when Hash
        if node[:infix] # binary operation
          return node_impure?(node[:lhs], self_name) || node_impure?(node[:rhs], self_name)

        elsif node[:cond] # ternary operation
          return node_impure?(node[:cond], self_name) ||
                 node_impure?(node[:e1], self_name) ||
                 node_impure?(node[:e2], self_name)

        elsif node[:op] # unary operation
          return node_impure?(node[:e], self_name)

        elsif node[:cmd_name] # command call
          name = node[:cmd_name].to_s

          cmd = get_command(name)
          return true unless name == self_name || cmd.pure?

          # check args
          Array(node[:args]).each do |a|
            return true if node_impure?(a, self_name)
          end

          return false

        elsif node[:base] && node[:chain] # chained command call
          return true if node_impure?(node[:base], self_name)

          node[:chain].each do |link|
            next_cmd = link[:next]
            name = next_cmd[:cmd_name].to_s

            cmd = get_command(name)
            return true unless name == self_name || cmd.pure?

            Array(next_cmd[:args]).each do |a|
              return true if node_impure?(a, self_name)
            end
          end

          return false

        elsif node[:var_name]
          return false # not impure unless a variable is mutated (cache is cleared on variable mutation)

        elsif node[:block] # a nested Block
          nested_block = Block.new(node[:block], node[:args], self, nil, self_name)
          return !nested_block.pure?

        elsif node[:array]
          return Array(node[:array]).any? { |a| node_impure?(a, self_name) } ||
                 (node[:subscript_idx] && node_impure?(node[:subscript_idx], self_name))

        elsif node[:string]
          return node[:subscript_idx] && node_impure?(node[:subscript_idx], self_name)

        elsif node[:bool] || node[:nil]
          return false

        else
          raise "Unknown node type: #{node.inspect}"
        end

      else
        raise "Unexpected node: #{node.inspect}"
      end
    end

  end

  #
  # Scans C/C++ source files for commands and expands them in place
  #
  class CFileInterpreter < Interpreter
    attr_reader :lines_parsed, :incomplete_files

    def initialize(file_list, out_path, cmd_prefix = COMMAND_PREFIX, extra_cmds = {}, extra_vars = {}, template_args=[],
                    safe: false, puritan: false, no_cache: false, cmd_cache: {})

      @EXTRA_CMDS, @EXTRA_VARS = extra_cmds, extra_vars
      super(cmd_prefix, extra_cmds, extra_vars, safe: safe, puritan: puritan, no_cache: no_cache, cmd_cache: cmd_cache)

      @file_list = file_list.is_a?(Array) ? file_list : [file_list]
      @current_file = nil
      @out_path = out_path

      @incomplete_files = []

      @lines_parsed = 0

      @template_args = template_args

      @recorded = ''
      @consume_mode = false
      @lick_mode = false

      @commands.merge!({
        embed: ->(filename, newline_steps=nil) {
          dir = File.dirname(@current_file || Dir.pwd)
          path = File.expand_path(filename, dir)
          raise "File not found: #{path}" unless File.exist? path
          File.binread(path).bytes.join(',')
        }.returns(String).impure
         .describe(
          'Reads all bytes from the specified file and joins them into a comma-separated String representation.'
        ),

        embed_hex: ->(filename, newline_steps=nil) {
          dir = File.dirname(@current_file || Dir.pwd)
          path = File.expand_path(filename, dir)
          raise "File not found: #{path}" unless File.exist? path
          bytes = File.binread(path).bytes
          bytes.map! {|b| b.to_i.to_hex }.join(',')
        }.returns(String).impure
         .describe(
          'Reads all bytes from the specified file and joins them as hex into a comma-separated String representation.'
        ),

        read: ->(filename) {
          dir = File.dirname(@current_file || Dir.pwd)
          path = File.expand_path(filename, dir)
          raise "File not found: #{path}" unless File.exist? path
          File.read(path)
        }.returns(String).impure
          .describe('Reads the file specified and returns its contents as a String.'),

        read_lines: ->(filename) {
          dir = File.dirname(@current_file || Dir.pwd)
          path = File.expand_path(filename, dir)
          raise "File not found: #{path}" unless File.exist? path
          File.readlines(path)
        }.returns(Array).impure
          .describe('Reads the file specified and returns an Array containing each line.'),

        read_bytes: ->(filename) {
          dir = File.dirname(@current_file || Dir.pwd)
          path = File.expand_path(filename, dir)
          raise "File not found: #{path}" unless File.exist? path
          File.binread(path).bytes
        }.returns(Array).impure
          .describe('Reads the file specified and returns an Array containing each byte.'),

        import: ->(template_file, *arg_vals) {
          t_interpreter = CFileInterpreter.new(nil,nil,@COMMAND_PREFIX,@EXTRA_CMDS,@EXTRA_VARS,[*arg_vals])
          dir = File.dirname(@current_file || Dir.pwd)
          path = File.expand_path(template_file, dir)
          ret, _, t_args = t_interpreter.process_file(path)
          @lines_parsed += t_interpreter.lines_parsed
          if t_args.length > 0
            puts "WARNING".underline_yellow + ': '.yellow + "#{t_args.length} template arg#{'s' if t_args.length != 1}"\
                 " not used.".yellow
          end
          ret
        }.returns(String).impure
         .describe(
          "Takes a template file name and a value for each arg exported by the template. The template file is " \
          "processed by the interpreter, and the generated code is embedded into the current file."
        ),

        expect: ->(*arg_names) {
          argc, targc = @template_args.length, arg_names.length
          if targc != argc
            raise "#{argc} template arg#{'s' if argc != 1} given when #{targc} #{targc==1 ? 'is' : 'are'} required."
          end
          arg_names.each_with_index do |arg, i|
            Utils.valid_identifier_check(arg)
            @variables[arg.to_sym] = @template_args.first
            @template_args = @template_args.drop(1)
          end
        }.impure
          .describe(
          "Declares the variables that should be defined when importing the template. " \
          "This command is specific to CFileInterpreter."
        ),

        start_consume: -> { @consume_mode = true }.impure
          .describe(
            "Starts consume mode; the following parsed lines will stored in a variable held by the interpreter, which "\
            "can only be accessed by the 'spit' command. Consumed lines will not be put in the generated source file."
        ),

        end_consume: -> { @consume_mode = false }.impure
          .describe('Ends consume parse mode.'),

        start_lick: -> { @lick_mode = true }.impure
          .describe('Starts lick parse mode.'),

        end_lick: -> { @lick_mode = false }.impure
          .describe('Ends lick parse mode.'),

        spit: ->(retain = false) {
          ret = @recorded.clone
          @recorded.clear unless retain
          ret
        }.returns(String).impure
          .describe('Gets what was consumed or licked.'),

        clear_consumed: -> { @recorded.clear }.impure
          .describe('Clears the variable containing what was consumed or licked.'),
        
        clear_licked: -> { @recorded.clear }.impure
          .describe('Clears the variable containing what was licked or consumed.'),
      })
    end

    def run(verbose: true, debug: false)
      @file_list.each do |file|
        if verbose
          puts "Processing #{file}".cyan
        end

        out, success, _ = process_file(file, verbose: verbose, debug: debug)

        @incomplete_files << file unless success

        new_file_path = @out_path + '/' + file
        FileUtils.mkdir_p(File.dirname(new_file_path))
        File.write(new_file_path, out)
      end
    end

    def process_file(file_path, verbose: true, debug: false)
      raise "#{file_path} does not exist." unless File.exist?(file_path)

      @current_file = file_path

      success = true

      # cursor state
      in_comment = false
      in_string  = false
      in_expr    = false # TODO: multi-line expression parsing

      output = ''

      File.readlines(file_path).each_with_index do |line, lineno|
        cursor   = 0
        new_line = ""

        while cursor < line.length
          # stop parsing rest of line on single-line comment
          if !in_comment && !in_string && line[cursor, 2] == "//"
            new_line << line[cursor..-1]
            break

          # enter multi-line comment
          elsif !in_comment && !in_string && line[cursor, 2] == "/*"
            in_comment = true
            new_line << "/*"
            cursor += 2
            next

          # leave comment
          elsif in_comment && line[cursor, 2] == "*/"
            in_comment = false
            new_line << "*/"
            cursor += 2
            next

          # enter string
          elsif !in_comment && line[cursor] == '"'
            in_string = !in_string
            new_line << '"'
            cursor += 1
            next
          end

          # enter command
          if !in_comment && !in_string && line[cursor, @COMMAND_PREFIX.length] == @COMMAND_PREFIX &&
              (cursor == 0 || !/[0-9A-Za-z_]/.match?(line[cursor-1]))
            expr_src = line[(cursor + @COMMAND_PREFIX.length)..]
            begin
              tree    = @parser.parse(expr_src)
              rtree_s = tree.to_s.reverse

              # finds the end of the expression (hacky)
              expr_end = /\d+/.match(rtree_s[..rtree_s.index('__last_char__: '.reverse)].reverse).to_s
              if expr_end.empty?
                raise 'Could not find an end to expression on line; multi-line expressions are not yet supported'
              end
              last_paren = Integer(expr_end) + 1

              ast = @transformer.apply(tree)
              value = eval_expr(ast)
              @out_stack << value.to_s unless value.nil?
              new_line << @out_stack.join("\n") unless @out_stack.empty?
              @out_stack.clear

              cursor += @COMMAND_PREFIX.length + last_paren # move cursor past expression
              next

            rescue Parslet::ParseFailed => e
              puts "#{file_path}:#{lineno+1}: parse failed at expression".yellow
              puts 'ERROR'.underline_red + ": #{e.parse_failure_cause.ascii_tree}".red
            rescue Exception => e
              puts "#{file_path}:#{lineno+1}: parse failed at expression".yellow
              puts 'ERROR'.underline_red + ": #{debug ? e.detailed_message : e.to_s}".red
              # fall through, copy raw text instead
            end

            success = false
          end

          new_line << line[cursor]
          cursor += 1
        end

        new_line = (line != new_line && new_line.strip.empty?) ? '' : new_line

        if @consume_mode
          @recorded << new_line
        else
          @recorded << new_line if @lick_mode
          output << new_line
        end
        @lines_parsed += 1
      end
      [output, success, @template_args]
    end
  end

  class ASMFileInterpreter < Interpreter
    # TODO!!!
  end

  #
  # A read–eval–print loop environment for testing/learning the language
  #
  class REPL < Interpreter

    def initialize(cmd_prefix = COMMAND_PREFIX, extra_cmds = {}, extra_vars = {}, safe: false, puritan: false,
                   no_cache: false, cmd_cache: {})
      @EXTRA_CMDS, @EXTRA_VARS = extra_cmds, extra_vars
      super(cmd_prefix, extra_cmds, extra_vars, safe: safe, puritan: puritan, no_cache: no_cache, cmd_cache: cmd_cache)

      @running = true

      @commands.merge!({
        write: ->(x, filename)  {
          File.open(filename, "w") do |file|
            @out_stack << x unless x.nil?
            file.write(@out_stack.join("\n"))
            @out_stack.clear
            nil
          end
        }.impure
          .describe(
          "Writes the contents of the out-stack and the given argument to the file specified. " \
          "This command is unique to the REPL interpreter."
        ),

        embed: ->(filename, newline_steps=nil) {
          raise "File not found: #{filename}" unless File.exist? filename
          File.binread(filename).bytes.join(',')
        }.returns(String).impure
         .describe('Reads all bytes from the given file and joins them into a comma-separated String representation.'),

        embed_hex: ->(filename, newline_steps=nil) {
          raise "File not found: #{filename}" unless File.exist? filename
          bytes = File.binread(filename).bytes
          bytes.map! {|b| b.to_i.to_hex }.join(',')
        }.returns(String).impure
         .describe(
          'Reads all bytes from the given file and joins them as hex into a comma-separated String representation.'
        ),

        read: ->(filename) {
          raise "File not found: #{filename}" unless File.exist? filename
          File.read(filename)
        }.returns(String).impure
          .describe('Reads the file given and returns its contents as a String.'),

        read_lines: ->(filename) {
          raise "File not found: #{filename}" unless File.exist? filename
          File.readlines(filename)
        }.returns(Array).impure
          .describe('Reads the file specified and returns an Array containing each line.'),

        read_bytes: ->(filename) {
          raise "File not found: #{filename}" unless File.exist? filename
          File.binread(filename).bytes
        }.returns(Array).impure
          .describe('Reads the file specified and returns an Array containing each byte.'),

        import: ->(template_file, *arg_vals) {
          t_interpreter = CFileInterpreter.new(nil,nil,@COMMAND_PREFIX,@EXTRA_CMDS,@EXTRA_VARS,[*arg_vals])
          ret, _, t_args = t_interpreter.process_file(template_file)
          if t_args.length > 0
            puts "WARNING".underline_yellow + ': '.yellow + "#{t_args.length} template arg#{'s' if t_args.length != 1}"\
                 "not used.".yellow
          end
          ret
        }.returns(String).impure
         .describe(
          "Takes a template file name and a value for each arg exported by the template. The template file is " \
          "processed by the interpreter, and the generated code is embedded into the current file."
        ),

         exit: -> { @running = false }.impure
          .describe('Exits the current REPL interpreter session. This command is specific to the REPL interpreter.')
      })

    end

    def run(debug: false)
      loop do
        begin
          print '> '.purple; expr = STDIN.gets&.chomp&.strip
          next if expr.nil? || expr.empty?

          parsed_tree = @parser.parse(expr, root: :expression)
          puts "Parsed tree: #{parsed_tree.inspect}".blue if debug

          ast = @transformer.apply(parsed_tree)
          puts "Transf tree: #{ast.inspect}".blue if debug

          out = eval_expr(ast)

          @out_stack << out unless out.nil?
          output = @out_stack.join("\n")

          output = "#<struct NCPP::Block ..." if output.start_with?("#<struct NCPP::Block")

          puts output.cyan
          @out_stack.clear

          break unless @running

        rescue Interrupt # Ctrl+C on windows to exit
          break
        rescue Parslet::ParseFailed => e
          puts 'ERROR'.underline_red + ": #{e.parse_failure_cause.ascii_tree}".red
        rescue Exception => e
          puts 'ERROR'.underline_red + ": #{debug ? e.detailed_message : e.to_s }".red
        end
      end
    end

  end


  class NCPPFileInterpreter < Interpreter

    def initialize(cmd_prefix = COMMAND_PREFIX, extra_cmds = {}, extra_vars = {}, safe: false, puritan: false,
                   no_cache: false, cmd_cache: {})
      super(cmd_prefix, extra_cmds, extra_vars, safe: safe, puritan: puritan, no_cache: no_cache, cmd_cache: cmd_cache)

      @running = true

      @exit_code = 0

      @commands.merge!({
        write: ->(x, filename)  {
          File.open(filename, "w") do |file|
            @out_stack << x unless x.nil?
            file.write(@out_stack.join("\n"))
            @out_stack.clear
            nil
          end
        }.impure
          .describe(
          "Writes the contents of the out-stack and the given argument to the file specified. " \
          "This command is unique to the REPL interpreter."
        ),

        read: ->(filename) {
          raise "File not found: #{filename}" unless File.exist? filename
          File.read(filename)
        }.returns(String).impure
          .describe('Reads the file given and returns its contents as a String.'),

        read_lines: ->(filename) {
          raise "File not found: #{filename}" unless File.exist? filename
          File.readlines(filename)
        }.returns(Array).impure
          .describe('Reads the file specified and returns an Array containing each line.'),

        read_bytes: ->(filename) {
          raise "File not found: #{filename}" unless File.exist? filename
          File.binread(filename).bytes
        }.returns(Array).impure
          .describe('Reads the file specified and returns an Array containing each byte.'),

         exit: ->(exit_code = 0) { @exit_code = exit_code; @running = false }.impure
          .describe('Exits the program.')
      })

    end

    def run(ncpp_file, debug: false)
      File.readlines(ncpp_file).each do |line|
        begin
          line = line.strip
          next if line.empty? || line.start_with?('//')

          eval_str(line)

          break unless @running

        rescue Parslet::ParseFailed => e
          puts 'ERROR'.underline_red + ": #{e.parse_failure_cause.ascii_tree}".red
          @exit_code = 1
          break
        rescue Exception => e
          puts 'ERROR'.underline_red + ": #{debug ? e.detailed_message : e.to_s}".red
          @exit_code = 1
          break
        end
      end

      @exit_code
    end

  end

end
