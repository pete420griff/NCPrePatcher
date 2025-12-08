require 'parslet'

module NCPP

  #
  # Parses raw text into a tree
  #
  class Parser < Parslet::Parser

    def initialize(cmd_prefix: 'ncpp_')
      @COMMAND_PREFIX = cmd_prefix
    end

    def parse(str, root: :line)
      send(root).parse(str)
    end

    root :line

    rule :line do
      space? >>
      ((str('//')|str('/*')|str('"')).absent? >> expression >> (any.repeat)).maybe >>
      any.repeat
    end

    rule :expression do
      ternary_operation | binary_operation | unary_operation | body
    end

    rule :body do
      float | integer | boolean | null | string | command | block | array | variable
    end

    rule :binary_operation do
      infix_expression(spaced(unary_operation|primary),
        [match['*/%'],        11, :left], # mul, div, modulo
        [match['+-'],         10, :left], # add, sub
        [str('<<')|str('>>'), 9,  :left], # bitwise left/right shift 
        [str('<=>'),          8,  :left], # three-way comparison
        [match['><'] >> str('=').maybe,
                              7,  :left], # relational >, ≥, <, ≤
        [str('==')|str('!='), 6,  :left], # relational =, ≠
        [str('&&'),           2,  :left], # logical AND
        [str('||'),           1,  :left], # logical OR
        [str('&'),            5,  :left], # bitwise AND
        [str('^'),            4,  :left], # bitwise XOR
        [str('|'),            3,  :left]  # bitwise OR
      )
    end

    rule :ternary_operation do
      (binary_operation|unary_operation|primary).as(:cond) >> spaced(str('?')) >> primary.as(:e1) >> spaced(str(':')) >> primary.as(:e2)
    end

    rule :unary_operation do
      match['!~\\-+*'].as(:op) >> primary.as(:e)
    end

    rule :primary do
      chained_command | command | variable | group | float | integer
    end

    rule(:group) { lparen >> (expression.as(:group) | str('').as(:empty_group)) >> rparen >> lbrace.absent? }

    rule(:identifier) { digits.absent? >> match['A-Za-z0-9_'].repeat(1) }

    rule :command do
      str(@COMMAND_PREFIX).maybe >> identifier.as(:cmd_name) >>
        lparen >>
          (expression >> (comma >> expression).repeat).repeat.as(:args) >>
        rparen.as(:__last_char__) >> subscript.maybe
    end

    rule(:boolean) { (str('true') | str('false')).as(:bool) }

    rule(:null) { (str('nil') | str('NULL')).as(:nil) }

    rule :variable do
      str(@COMMAND_PREFIX).maybe >> identifier.as(:var_name) >> lparen.absent? >> subscript.maybe
    end

    rule :block do
      block_args.maybe >> lbrace >> expression.repeat.as(:block_body) >> rbrace >> subscript.maybe
    end

    rule :block_args do
      lparen >>
        (identifier >> (comma >> identifier).repeat).as(:block_args).maybe >>
      rparen
    end

    # rule :block_sequence do
    #   block_args.maybe >> lbrace >>
    #     (block >> (comma >> block).repeat).as(:block_sequence) >>
    #   rbrace >> subscript.maybe
    # end

    rule :array do
      lbracket >>
        (expression >> (comma >> expression).repeat).maybe.as(:array) >>
      rbracket >> subscript.maybe
    end

    rule :chained_command do
      (command|boolean|null|variable|group|block|array|float|integer|string).as(:base) >>
        (str('.') >> command.as(:next)).repeat.as(:chain) >> subscript.maybe
    end

    rule :subscript do
      lbracket >> expression.as(:subscript_idx) >> rbracket
    end

    rule(:space) { match['\s'].repeat(1) }
    rule(:space?) { space.maybe }

    def spaced(atom)
      space? >> atom >> space?
    end

    rule(:comma)  { spaced(str(',')) }
    rule(:lparen)  { spaced(str('(')) }
    rule(:rparen)  { spaced(str(')')) }
    rule(:lbrace)  { spaced(str('{')) }
    rule(:rbrace)  { spaced(str('}')) }
    rule(:lbracket) { spaced(str('[')) }
    rule(:rbracket) { spaced(str(']')) }
    rule(:newline) { str("\n") >> str("\r").maybe }
    rule(:eol)    { str("\n") | any.absent? }
    rule(:digit)  { match['0-9'] }
    rule(:digits)  { digit.repeat(1) }
    rule(:hex_digit)  { match['0-9a-fA-F'] }
    rule(:hex_digits) { hex_digit.repeat(1) }
    rule(:bin_digit)  { match['0-1'] }
    rule(:bin_digits) { bin_digit.repeat(1) }

    rule :float do
      (digits.maybe >>
        (
          (
            str('.')|str('e')) >>
            match['+-'].maybe >> digits
          ) >>
        (
          str('e') >>
          match['+-'].maybe >>
          digits
        ).maybe
      ).as(:float) >> space?
    end

    rule :integer do
      (
        (
        (str('0x') >> hex_digits) |
        (str('0b') >> bin_digits) |
        digits)
      ).as(:integer) >> space?
    end

    rule :string do
      (str('"') >> (
        str('\\') >> any | str('"').absent? >> any
      ).repeat.as(:string) >> str('"')) |
      (str("'") >> (
        str('\\') >> any | str("'").absent? >> any
      ).repeat.as(:string) >> str("'")) >> subscript.maybe
    end

  end

  #
  # Transforms parsed trees to ASTs
  #
  class Transformer < Parslet::Transform
    rule(integer: simple(:x)) { Integer(x) }
    rule(float: simple(:x))   { Float(x) }
    rule(string: simple(:s))  { String(s) }
    rule(string: sequence(:s)) { '' }

    rule(array: subtree(:a)) do
      { array:
        case a
        when nil then []
        when Array then a
        else [a]
        end
      }
    end

    rule(group: subtree(:g)) { g }
    rule(empty_group: simple(:g)) { nil }

    rule(l: subtree(:lhs), o: simple(:op), r: subtree(:rhs)) do
      { infix: true, lhs: lhs, op: op.to_s, rhs: rhs }
    end

    rule(cond: subtree(:cond), e1: subtree(:e1), e2: subtree(:e2)) do
      { cond: cond, e1: e1, e2: e2 }
    end

    rule(op: simple(:op), e: subtree(:e)) do
      { op: op.to_s, e: e }
    end

    rule(cmd_name: simple(:n), args: subtree(:a)) do
      args =
        case a
        when nil   then []
        when Array then a
        else [a]
        end

      { cmd_name: n.to_s, args: args }
    end

    rule(base: subtree(:b), chain: sequence(:cs)) do
      { base: b, chain: cs }
    end

    rule(block_body: subtree(:exprs)) do
      { block: 
        case exprs
        when nil
          []
        when Array
          exprs.compact
        else
          [exprs]
        end
      }
    end

    rule(block_args: simple(:args), block_body: subtree(:exprs)) do
      { block: 
        case exprs
        when nil
          []
        when Array
          exprs.compact
        else
          [exprs]
        end,
        args: args.to_s.split(',').map(&:strip)
      }
    end

  end

end
