require 'parslet'

module NCPP

  class Parser < Parslet::Parser

    def initialize(cmd_prefix: 'ncpp_')
      @COMMAND_PREFIX = cmd_prefix
    end

    def parse(str, root: :line, **opts)
      send(root).parse(str, **opts)
    end

    rule :line do
      space? >>
      ((str('//')|str('/*')|str('"')).absent? >> expression >> (any.repeat)).maybe >>
      any.repeat
    end

    rule :expression do
      binary_operation | body
    end


    rule :body do
      float | integer | string | boolean | command | block
    end

    rule :binary_operation do
      infix_expression(spaced(primary),
        [match['*/%'],        8, :left], # mul, div, modulo
        [match['+-'],         7, :left], # add, sub
        [str('<<')|str('>>'), 6, :left], # bitwise left/right shift 
        [str('==')|str('!='), 5, :left], # relational =, ≠
        [match['><'] >> str('=').maybe,
                              4, :left], # relational >, ≥, <, ≤
        [str('&'),            3, :left], # bitwise AND
        [str('^'),            2, :left], # bitwise XOR
        [str('|'),            1, :left]  # bitwise OR
      ) | infix_expression(spaced(string | chained_command),
          [str('+')|str('<<')| # string concatenation
           str('==')|str('!='), # string comparison
           1, :left])
    end

    rule :primary do
      chained_command | command | variable | group | float | integer
    end

    rule(:group) { lparen >> expression.as(:group) >> rparen }

    rule(:identifier) { digits.absent? >> match['A-Za-z0-9_'].repeat(1) }

    rule :command do
      str(@COMMAND_PREFIX).maybe >> identifier.as(:cmd_name) >>
        lparen >>
          (expression >> (comma >> expression).repeat).repeat.as(:args) >>
        rparen.as(:__outer_paren__)
    end
    
    rule(:boolean) { (str('true') | str('false')).as(:bool) }

    rule :variable do
      str(@COMMAND_PREFIX).maybe >> identifier.as(:var_name) >> lparen.absent? >> space?
    end


    rule :block do
      lbrace >> expression.repeat.as(:block_body) >> rbrace
    end

    rule :chained_command do
      (command|boolean|variable|group|block|float|integer|string).as(:base) >> (str('.') >> command.as(:next)).repeat.as(:chain)
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
    rule(:newline) { str("\n") >> str("\r").maybe }
    rule(:eol)    { str("\n") | any.absent? }
    rule(:digit)  { match['0-9'] }
    rule(:digits)  { digit.repeat(1) }
    rule(:hex_digit)  { match['0-9a-fA-F'] }
    rule(:hex_digits) { hex_digit.repeat(1) }
    rule(:bin_digit)  { match['0-1'] }
    rule(:bin_digits) { bin_digit.repeat(1) }

    rule :float do
      (
        str('-').maybe >>
        digits.maybe >>
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
      (str('-').maybe >> (
        (str('0x') >> hex_digits) |
        (str('0b') >> bin_digits) |
        digits)
      ).as(:integer) >> space?
    end

    rule :string do
      str('"') >> (
        str('\\') >> any | str('"').absent? >> any
      ).repeat.as(:string) >> str('"')
    end

  end


  class Transformer < Parslet::Transform
    rule(integer: simple(:x)) { Integer(x) }
    rule(float: simple(:x))   { Float(x) }
    rule(string: simple(:s))  { String(s) }

    rule(group: subtree(:g)) { g } # unwrap parentheses

    rule(l: subtree(:lhs), o: simple(:op), r: subtree(:rhs)) do
      { infix: true, lhs: lhs, op: op.to_s, rhs: rhs }
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

  end

end
