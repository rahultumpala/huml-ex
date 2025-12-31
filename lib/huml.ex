defmodule HUML do
  @moduledoc """
  Documentation for `HUML`.
  """

  import Huml.{Vsn, Helpers, Tokenizer, Root}

  def decode(str) do
    try do
      tokens = tokenize(str)

      if length(tokens) == 0 do
        {:error, "Empty document."}
      else
        reject!(tokens, :whitespace)

        {:ok, parse(tokens)}
      end
    rescue
      e -> {:error, e}
    end
  end

  def parse(tokens) do
    {tokens, struct} = parse_vsn(tokens)
    {struct, []} = parse_root(tokens, struct)

    Map.get(struct, :entries)
  end
end
