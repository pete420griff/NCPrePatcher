require_relative 'parser.rb'
require_relative 'commands.rb'

require 'fileutils'

module NCPP

  Block = Struct.new(:ast,:args,:interpreter) do
    def eval(argv)
      result = nil
      ast.each {|node| result = interpreter.eval_expr(node, argv.empty? || args.nil? ? nil : Hash[args.zip(argv)]) }
      result
    end
    def call(*argv) = eval(argv)
    def return_type = Object
    def cacheable? = false
  end

  #
  # Evaluates and executes NCPP DSL ASTs
  #
  class Interpreter
    def initialize(cmd_prefix = COMMAND_PREFIX, extra_cmds = {}, extra_vars = {}, cmd_cache = {})
      @parser = Parser.new(cmd_prefix: cmd_prefix)
      @transformer = Transformer.new

      @COMMAND_PREFIX = cmd_prefix

      # interpreter environment-specific commands
      @commands = CommandRegistry.new({
        put: ->(x, new_line=true) {
          if new_line
            @out_stack << String(x)
          else
            @out_stack[-1] << String(x)
          end
        },
        top_of_out_stack: -> { @out_stack[0] }.returns(String),
        end_of_out_stack: -> { @out_stack[-1] }.returns(String),
        clear_out_stack: -> { @out_stack.clear },
        ruby: ->(code_str) { eval(code_str, get_binding) },
        do_command: ->(cmd_str, *args) { @commands[cmd_str.to_sym].call(*args) }.returns(Object),
        define_command: ->(name, block) {
          Utils::valid_identifier_check(name)
          @commands[name.to_sym] = block.is_a?(Block) ? block : eval(block, get_binding)
        },
        alias_command: ->(new_name, name) {
          Utils::valid_identifier_check(name)
          @commands[new_name.to_sym] = @commands[name.to_sym]
        },
        define_variable: ->(name, val) {
          Utils::valid_identifier_check(name)
          @variables[name.to_sym] = eval_expr(val)
        },

        embed: ->(filename, newline_steps=nil) {
          dir = File.dirname(@current_file || Dir.pwd)
          path = File.expand_path(filename, dir)
          raise "File not found: #{path}" unless File.exist? path
          File.binread(path).bytes.join(',')
        }.returns(String),

        embed_hex: ->(filename, newline_steps=nil) {
          dir = File.dirname(@current_file || Dir.pwd)
          path = File.expand_path(filename, dir)
          raise "File not found: #{path}" unless File.exist? path
          bytes = File.binread(path).bytes
          bytes.map! {|b| b.to_i.to_hex }.join(',')
        }.returns(String),

        include: ->(filename) {
          dir = File.dirname(@current_file || Dir.pwd)
          path = File.expand_path(filename, dir)
          raise "File not found: #{path}" unless File.exist? path
          File.read(path)
        }.returns(String)
      },

      aliases: {
        out:        :put,
        do_cmd:     :do_command,
        define_cmd: :define_command,
        alias_cmd:  :alias_command,
        define_var: :define_variable

      }).merge(CORE_COMMANDS)
        .merge(extra_cmds)

      @variables = {
        SYMBOL_COUNT: Unarm.symbols.count,
        OVERLAY_COUNT: $rom.overlay_count,
        GAME_TITLE: $rom.header.game_title,
        NITRO_SDK_VERSION: $rom.nitro_sdk_version,
      }.merge(CORE_VARIABLES)
       .merge(extra_vars)

      @command_cache = cmd_cache # TODO

      @out_stack = []
      @current_file = nil
    end

    def get_binding
      binding
    end

    def eval_expr(node, subs = nil)
      case node
        when Numeric, String, Array
          node

        when Hash
          if node[:infix]
            lhs = eval_expr(node[:lhs], subs)
            rhs = eval_expr(node[:rhs], subs)
            lhs.send(node[:op], rhs)

          elsif node[:cmd_name] # normal command call
            cmd = @commands[node[:cmd_name].to_sym] or raise "Unknown command #{node[:cmd_name]}"
            args = Array(node[:args]).map { |a| eval_expr(a, subs) }
            ret = cmd.call(*args)
            cmd.return_type.nil? ? nil : (node[:subscript_idx].nil? ? ret : ret[eval_expr(node[:subscript_idx], subs)])

          elsif node[:base] && node[:chain] # chained command call
            acc = eval_expr(node[:base], subs)
            no_ret = false
            node[:chain].each do |link|
              next_cmd = link[:next]
              cmd = @commands[next_cmd[:cmd_name].to_sym] or raise "Unknown command #{next_cmd[:cmd_name]}"
              args = Array(next_cmd[:args]).map { |a| eval_expr(a, subs) }
              acc = cmd.call(acc, *args)
              no_ret = cmd.return_type.nil?
            end
            no_ret ? nil : acc

          elsif node[:var_name]
            if !subs.nil?
              ret = subs[node[:var_name].to_s]
              puts ret
              puts node[:subscript_idx]
              return (node[:subscript_idx].nil? ? ret : ret[eval_expr(node[:subscript_idx], subs)]) unless ret.nil?
            end
            ret = @variables[node[:var_name].to_sym] or raise "Unknown variable: #{node[:var_name]}"
            node[:subscript_idx].nil? ? ret : ret[eval_expr(node[:subscript_idx], subs)]

          elsif node[:block]
            Block.new(node[:block], node[:args], self)

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
            eval(node[:bool])

          elsif node[:nil]
            nil

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
    def initialize(file_list, out_path, cmd_prefix = COMMAND_PREFIX, extra_cmds = {}, extra_vars = {})
      super(cmd_prefix, extra_cmds, extra_vars)
      @file_list = file_list.is_a?(Array) ? file_list : [file_list]
      @out_path = out_path
    end

    def run(verbose: true)
      @file_list.each { process_file(it, verbose: verbose) }
    end

    def process_file(file_path, verbose: true)
      raise "#{file_path} does not exist." unless File.exist?(file_path)

      @current_file = file_path

      puts "Processing #{file_path}" if verbose

      new_file_path = @out_path + '/' + file_path

      # cursor state
      in_comment = false
      in_string  = false

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
              last_paren = Integer(/\d+/.match(rtree_s[..rtree_s.index('__last_char__: '.reverse)].reverse).to_s) + 1

              ast = @transformer.apply(tree)
              value = eval_expr(ast)
              @out_stack << value.to_s unless value.nil?
              new_line << @out_stack.join("\n") unless @out_stack.empty?
              @out_stack.clear

              # puts "#{file_path}:#{lineno+1} expanded #{@COMMAND_PREFIX}..." if verbose

              cursor += @COMMAND_PREFIX.length + last_paren # move cursor past command expression
              next
            rescue Parslet::ParseFailed => e
              warn "#{file_path}:#{lineno+1}: parse failed at expression"
              warn e.parse_failure_cause.ascii_tree
              # fall through, copy raw text instead
            end
          end

          new_line << line[cursor]
          cursor += 1
        end

        output << new_line unless line != new_line && new_line.strip.empty?
      end

      FileUtils.mkdir_p(File.dirname(new_file_path))
      File.write(new_file_path, output)
    end
  end

  #
  # A read–eval–print loop environment for testing/learning the language
  #
  class REPL < Interpreter

    def run(debug = false)
      loop do
        begin
          print '> '; expr = STDIN.gets.chomp
          next if expr.empty?

          parsed_tree = @parser.parse(expr, root: :expression)
          puts "Parsed tree: #{parsed_tree.inspect}" if debug
          ast = @transformer.apply(parsed_tree)
          puts "Transf tree: #{ast.inspect}" if debug
          out = eval_expr(ast)
          @out_stack << out unless out.nil?
          puts @out_stack.join("\n")
          @out_stack.clear

        rescue Parslet::ParseFailed => error
          puts "ERROR: " + error.parse_failure_cause.ascii_tree.to_s
        rescue ArgumentError => error
          puts "ERROR: " + error.to_s
        rescue RuntimeError => error
          puts "ERROR: " + error.to_s

        rescue Interrupt # Ctrl+C on windows to exit
          exit
        end
      end
    end

  end

end
