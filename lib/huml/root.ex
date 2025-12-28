defmodule Huml.Root do
  import Huml.{Helpers}

  def parse_root({struct, [cur | _rest] = tokens}) do
    case cur do
      {_line, _col, :square_bracket_open} ->
        parse_empty_list(struct, tokens)

      {_line, _col, :curly_bracket_open} ->
        parse_empty_dict(struct, tokens)

      _ ->
        {next, rest} = read_until(tokens, [:whitespace, ",", :newline, :colon, :eol]) |> dbg()

        check_key(next)

        {struct, rest}
    end
  end

  defp parse_empty_list(struct, tokens) do
    with [cur, next] <- tokens,
         {_line, _col, :square_bracket_open} <- cur,
         {_line, _col, :square_bracket_close} <- next do
      struct
    else
      _ ->
        raise Huml.ParseError,
          message:
            "Doc begins with an open square bracket. Expected empty list in the doc. But got #{join_tokens(tokens)}"
    end
  end

  defp parse_empty_dict(struct, tokens) do
    with [cur, next] <- tokens,
         {_line, _col, :curly_bracket_open} <- cur,
         {_line, _col, :curly_bracket_close} <- next do
      struct
    else
      _ ->
        raise Huml.ParseError,
          message:
            "Doc begins with an open curly bracket. Expected empty dict in the doc. But got #{join_tokens(tokens)}"
    end
  end
end
