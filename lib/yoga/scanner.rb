# encoding: utf-8
# frozen_string_literal: true

module Yoga
  # A scanner.  This performs scanning over a series of tokens.
  # It is built to lazily scan whenever it is required, instead
  # of all at once.  This integrates nicely with the parser.
  module Scanner
    # @overload call(&block)
    #   For every token that is scanned, the block is yielded to.
    #
    #   @yieldparam token [Scanner::Token]
    #   @return [self]
    # @overload call
    #   Returns an enumerable over the tokens in the scanner.
    #
    #   @return [::Enumerable<Scanner::Token>]
    def call(source)
      return to_enum(:call, source) unless block_given?
      @scanner = StringScanner.new(source)
      @line = 1

      until @scanner.eos?
        value = scan
        yield value if value.is_a?(Token)
      end

      yield Token.eof(location)
      self
    end

    # The scanning method.  This should return one of two values: a {Token},
    # or `true`.  `nil` should _never_ be returned.  This performs an
    # incremental scan of the document; it returns one token at a time.  If
    # something matched, but should not emit a token, `true` should be
    # returned.  The implementing class should mark this as private or
    # protected.
    #
    # @abstract
    #   Please implement this method in order to make the class a scanner.
    # @return [Yoga::Token, true]
    def scan
      fail NotImplementedError, "Please implement #{self.class}#scan"
    end

  private

    # Returns a location at the given location.  If a size is given, it reduces
    # the column number by the size and returns the size from that.
    #
    # @example
    #   @scanner.string # => "hello"
    #   @line # => 1
    #   @scanner.charpos # => 5
    #   location # => #<Yoga::Location <anon>:1.6>
    #   location(5) # => #<Yoga::Location <anon>:1.1-6
    # @param size [::Numeric] The size of the token.
    # @return [Yoga::Location]
    def location(size = 0)
      start = (@scanner.charpos - distance_from_line) + 1
      column = (start - size)..start
      Location.new(file, @line, column)
    end

    # Creates a scanner token with the given name and source.  This grabs the
    # location using {#location}, setting the size to the size of the source
    # text.  The source is frozen before initializing the token.
    #
    # @example
    #   emit(:<, "<") # => #<Yoga::Token kind=:< source="<">
    # @return [Yoga::Token]
    def emit(kind, source = @scanner[0])
      Token.new(kind.freeze, source.freeze, location(source.length))
    end

    # Attempts to match the given token.  The first argument can be a string,
    # a symbol, or a regular expression.  If the matcher is a symbol, it's
    # coerced into a regular expression, with a forward negative assertion for
    # any alphanumeric characters, to prevent partial matches (see
    # {#symbol_negative_assertion}).  If the matcher is a regular expression,
    # it is left alone.  Otherwise, `#to_s` is called and passed to
    # `Regexp.escape`.  If the text is matched at the current position, a token
    # is returned; otherwise, nil is returned.
    #
    # @param matcher [::Symbol, ::Regexp, #to_s]
    # @param kind [::Symbol] The kind of token to emit.  This defaults to a
    #   symbol version of the matcher.
    # @return [Yoga::Token, nil]
    def match(matcher, kind = :"#{matcher}")
      matcher = case matcher
                when ::Symbol then /#{::Regexp.escape(matcher.to_s)}#{symbol_negative_assertion}/
                when ::Regexp then matcher
                else /#{::Regexp.escape(matcher.to_s)}/
                end


      ((kind && emit(kind)) || true) if @scanner.scan(matcher)
    end

    # The distance from the last line in the file.  This includes the start of
    # the file as well.
    #
    # @return [::Numeric]
    def distance_from_line
      @scanner.string.rindex(/\A|\r\n|\n\r|\n|\r/, @scanner.charpos)
    end

    # The negative assertion used for converting a symbol matcher to a regular
    # expression.  This is used to prevent premature matching of other
    # identifiers.  For example, if `module` is a keyword, and `moduleA` is
    # an identifier, this negative assertion allows the following expression
    # to properly match as such: `match(:module) || module(/[a-zA-Z], :IDENT)`.
    #
    # @return [#to_s]
    def symbol_negative_assertion
      "(?![a-zA-Z])"
    end

    # The file of the scanner.  This can be overwritten to provide a descriptor
    # for the file.
    #
    # @return [::String]
    def file
      @file ||= "<anon>"
    end
  end
end