# encoding: utf-8
# frozen_string_literal: true

require "fixtures/parser"
require "fixtures/scanner"

RSpec.describe Yoga::Parser do
  subject { Fixtures::Parser.new(tokens.call) }
  let(:tokens) { Fixtures::Scanner.new(source) }
  let(:source) { "b = a + 2;\nb * 2;\n" }
  let(:nodes) do
    n(:Root, children: [
      n(:Operation,
        kind: :+,
        left: n(:Operation,
          kind: :"=",
          left: n(:Identifier, name: "b", location: l(1..2)),
          right: n(:Identifier, name: "a", location: l(5..6)),
          location: l(1..6)),
        right: n(:Literal, value: "2", location: l(9..10)),
        location: l(1..10)),
      n(:Operation,
        kind: :*,
        left: n(:Identifier, name: "b", location: l(1..2, 2..2)),
        right: n(:Literal, value: "2", location: l(5..6, 2..2)),
        location: l(1..6, 2..2))
    ], location: l(1..10, 1..2))
  end

  it "parses" do
    expect(subject.call).to_not be nil
  end

  it "creates nodes" do
    expect(subject.call).to eq nodes
  end

  context "#first" do
    let(:set) { Set[:"=", :*, :/, :+, :-, :"^", :%] }
    it "contains a first set" do
      expect(subject.first(:Expression)).to eq set
    end

    it "fails for invalid sets" do
      expect { subject.first(:Something) }.to raise_error(::KeyError)
    end
  end

  context "at the end of a string" do
    before { subject.call }

    it "has an EOF token" do
      expect(subject.peek.kind).to eq :EOF
    end

    context "after the EOF token" do
      before { subject.expect([:EOF]) }

      it "repeats the EOF token" do
        expect(subject.peek.kind).to eq :EOF
      end

      it "fails on shift" do
        expect { subject.shift }.to raise_error(Yoga::InvalidShiftError)
      end
    end
  end

  context "with an invalid input" do
    let(:source) { "a = =" }

    it "fails to parse" do
      expect { subject.call }.to raise_error(Yoga::Error)
    end
  end

  context "#peek_out" do
    it "properly peeks" do
      expect(subject.peek_out(2).kind).to eq :IDENT
    end

    it "returns the same value" do
      10.times do
        expect(subject.peek_out(2).kind).to eq :IDENT
      end
    end

    context "with a far out index" do
      it "returns the last available token" do
        expect(subject.peek_out(999).kind).to eq :EOF
      end
    end
  end

  context "#push_out?" do
    it "properly peeks" do
      expect(subject.peek_out?(2, [:IDENT])).to be true
      expect(subject.peek_out?(1, [:NOPE])).to be false
    end
  end

  context "#push" do
    it "makes a token peek" do
      token = subject.shift
      subject.push(token)
      expect(subject.peek).to be token
    end

    it "makes a token shift" do
      token = subject.shift
      subject.push(token)
      expect(subject.shift).to be token
    end
  end

  context "#collect" do
    context "without a join" do
      let(:source) { "= = = = =" }

      it "parses properly" do
        collected = subject.collect([:EOF]) { subject.expect([:"="]) }
        expect(collected.size).to be 5
      end
    end

    context "With a join" do
      let(:source) { "= + = + = =" }

      it "parses properly" do
        collected = subject.collect([:EOF], [:+]) { subject.expect([:"="]) }
        expect(collected.size).to be 3
      end
    end
  end

  context "#peek?" do
    it "requires an enumerable" do
      expect { subject.peek?(:"=") }.to raise_error(::NoMethodError)
    end
  end

  def n(name, opts)
    Fixtures::Parser.const_get(name).new(opts)
  end

  def l(column, line = 1..1, file = "<anon>")
    Yoga::Location.new(file, line, column)
  end
end
