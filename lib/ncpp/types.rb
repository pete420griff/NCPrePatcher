require_relative 'utils.rb'

module NCPP

  Block = Struct.new(:ast, :argns, :interpreter, :subs, :name) do
    def eval(args)
      result = nil
      ast.each do |node|
        if subs.nil?
          result = interpreter.eval_expr(node, args.empty? || argns.nil? ? nil : Hash[argns.zip(args)])
        else
          result = interpreter.eval_expr(node, args.empty? || argns.nil? ? subs : subs.merge(Hash[argns.zip(args)]))
        end
      end
      result
    end

    def call(*args) = eval(args)

      # if no_cache.nil? && pure?
        # @cache ||= {}
        # return @cache[args] if @cache.key?(args)
        # result = eval(args)
        # @cache[args] = result
        # return result
      # else
        # return eval(args)
      # end

    def return_type = Object

    def arg_names = argns

    def pure?
      @pure unless @pure.nil?
      @pure = !ast.any? { |n| interpreter.node_impure?(n, name) }
    end
  end

  # The following are not yet (and may never be) implemented

  Boolean = Struct.new(:truthy) do
    def true? = truthy
    def false? = !truthy
  end

  class CodeLoc
    attr_reader :addr, :ov, :code_bin

    def initialize(loc, ov = nil)
      @addr, @ov, @code_bin = Utils::resolve_code_loc(loc, ov)
    end
  end

  class AsmFunc
    attr_reader :instructions, :labels, :literal_pool

    def initialize(instructions, labels, literal_pool)
      @instructions = instructions
      @labels = labels
      @literal_pool = literal_pool
    end

    def to_s(reloc: true)
    end
  end

end
