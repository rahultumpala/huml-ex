defmodule HUML do
  @moduledoc """
  Documentation for `HUML`.
  """

  import Huml.{Vsn, Helpers, Tokenizer, Root}

  def hello do
    :i_am_huml
  end

  def decode(str) do
    tokens = tokenize(str)

    if length(tokens) == 0 do
      %{}
    else
      reject!(Enum.at(tokens, 0), :whitespace)

      parse(tokens)
    end
  end

  def parse(tokens) do
    {tokens, struct} = parse_vsn(tokens)
    parse_root(tokens, struct) |> dbg
  end
end
