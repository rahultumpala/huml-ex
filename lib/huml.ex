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
      try do
        reject!(Enum.at(tokens, 0), :whitespace)

        {:ok, parse(tokens)}
      rescue
        e ->
          {:error, e}
      end
    end
  end

  def parse(tokens) do
    {tokens, struct} = parse_vsn(tokens)
    {struct, []} = parse_root(tokens, struct)

    Map.get(struct, :entries)
  end
end
