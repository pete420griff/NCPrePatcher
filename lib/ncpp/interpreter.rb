require_relative 'parser.rb'
require_relative 'commands.rb'

require 'fileutils'

module NCPP

  Block = Struct.new(:ast,:interpreter) do
    def eval
      result = nil
      ast.each {|node| result = interpreter.eval_expr(node) }
      result
    end
    def call(_=nil) = eval
    def return_type = nil
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
      @commands = {
        ruby: ->(code_str) { eval(code_str, get_binding) },
        call_command: ->(cmd_str, *args) { @commands[cmd_str.to_sym].call(*args) },
        define_command: ->(name,block) do
          Utils::valid_identifier_check(name)
          @commands[name.to_sym] = block.is_a?(Block) ? block : eval(block, get_binding)
        end,
        alias_command: ->(new_name, name) do
          Utils::valid_identifier_check(name)
          @commands[new_name.to_sym] = @commands[name.to_sym]
        end,
        define_variable: ->(name, val) do
          Utils::valid_identifier_check(name)
          @variables[name.to_sym] = eval_expr(val)
        end,
        alias_variable: ->(new_name, name) do
          Utils::valid_identifier_check(name)
          @variables[new_name.to_sym] = @variables[name.to_sym]
        end
      }.merge(CORE_COMMANDS)
       .merge(extra_cmds)

      @variables = CORE_VARIABLES.merge(extra_vars)

      @command_cache = cmd_cache # TODO
    end

    def get_binding
      binding
    end

    def eval_expr(node)
      case node
        when Numeric, String
          node

        when Hash
          if node[:infix]
            lhs = eval_expr(node[:lhs])
            rhs = eval_expr(node[:rhs])
            lhs.send(node[:op], rhs)

          elsif node[:cmd_name] # normal command call
            fn = @commands[node[:cmd_name].to_sym] or raise "Unknown command #{node[:cmd_name]}"
            args = Array(node[:args]).map { |a| eval_expr(a) }
            ret = fn.call(*args)
            fn.return_type.nil? ? nil : ret

          elsif node[:base] && node[:chain] # chained command call
            acc = eval_expr(node[:base])
            no_ret = false
            node[:chain].each do |link|
              cmd = link[:next]
              fn = @commands[cmd[:cmd_name].to_sym] or raise "Unknown command #{cmd[:cmd_name]}"
              args = Array(cmd[:args]).map { |a| eval_expr(a) }
              acc = fn.call(acc, *args)
              no_ret = fn.return_type.nil?
            end
            no_ret ? nil : acc

          elsif node[:var_name]
            @variables[node[:var_name].to_sym] or raise "Unknown variable: #{node[:var_name]}"

          elsif node[:block]
            Block.new(node[:block], self)

          elsif node[:bool]
            eval(node[:bool])

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

      puts "Processing #{file_path}" if verbose

      new_file_path = @out_path + '/' + file_path

      # cursor state
      in_comment = false
      in_string  = false

      output = []

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

              # EXTREMELY HACKY BUT FOR NOW FUCK IT I DON'T CARE I DON'T CARE I DON'T CARE NO ONE CAN MAKE ME CARE
              # (finds the end of the expression)
              last_paren = Integer(/\d+/.match(rtree_s[..rtree_s.index('__outer_paren__: '.reverse)].reverse).to_s) + 1

              ast = @transformer.apply(tree)
              value = eval_expr(ast)
              new_line << value.to_s

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

        output << new_line unless line != new_line && /$\s*^/.match?(new_line)
      end

      FileUtils.mkdir_p(File.dirname(new_file_path))
      File.write(new_file_path, output.join)
    end
  end

  #
  # A read–eval–print loop environment for testing/learning the language
  #
  class REPL < Interpreter

    def run
      loop do
        begin
          print '> '; expr = STDIN.gets.chomp
          next if expr.empty?

          parsed_tree = @parser.parse(expr, root: :expression)
          ast = @transformer.apply(parsed_tree)
          puts eval_expr(ast)

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
