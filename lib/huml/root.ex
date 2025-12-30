defmodule Huml.Root do
  import Huml.{Helpers}

  def parse_root([], struct) do
    {struct, []}
  end

  def parse_root([cur | _rest] = tokens, struct) do
    case cur do
      {_, _, :eol} ->
        consume(tokens, 1) |> parse_root(struct)

      {_line, _col, :square_bracket_open} ->
        parse_empty_list(struct, tokens)

      {_line, _col, :curly_bracket_open} ->
        parse_empty_dict(struct, tokens)

      _ ->
        {next_seq, rest} = read_until(tokens, [:whitespace, ",", :newline, :colon, :eol])

        [first, second | _rest] = rest

        {struct, rest} =
          case first do
            {_, _, :colon} ->
              case second do
                {_, _, :colon} ->
                  parse_vector(tokens, struct)

                {_, _, :whitespace} ->
                  parse_inline_dict(tokens, struct)

                {line, col, tok} ->
                  raise Huml.ParseError,
                    message: "Unexpected character #{tok} at line:#{line} col:#{col}"
              end

            {_, _, ","} ->
              parse_inline_list(tokens, struct)

            {_, _, :eol} ->
              cond do
                length(next_seq) == 0 ->
                  tokens |> consume(1) |> parse_root(struct)

                length(next_seq) > 0 ->
                  struct =
                    struct
                    |> Map.update(:entries, [], fn val ->
                      [join_tokens(next_seq) |> normalize_tokens() |> dbg] ++ val
                    end)

                  rest |> consume(1) |> parse_root(struct)
              end

            {line, col, :whitespace} ->
              raise Huml.ParseError, message: "Unexpected whitespace at line:#{line} col:#{col}."
          end

        {struct, rest}
    end
  end

  defp parse_inline_list([], struct) do
    {struct, []}
  end

  defp parse_inline_list([cur | rest] = tokens, struct) do
    case cur do
      {_, _, :eol} ->
        {struct, rest}

      {_, _, :whitespace} ->
        parse_inline_list(rest, struct)

      {_, _, ","} ->
        parse_inline_list(rest, struct)

      _ ->
        {seq, rest} = read_until(tokens, [",", :whitespace, :eol])
        struct = update_entries(seq, struct)
        parse_inline_list(rest, struct)
    end
  end

  defp parse_inline_dict([], struct) do
    {struct, []}
  end

  defp parse_inline_dict(tokens, struct) do
    dbg(struct)

    {seq, rest} = read_until(tokens, [:colon, :eol])

    if length(seq) == 0 do
      {struct, rest}
    else
      key = join_tokens(seq) |> normalize_tokens(:dict_key)

      rest =
        expect!(rest, :colon)
        |> expect!(:whitespace)

      {seq, rest} = read_until(rest, [:whitespace, ",", :eol])
      value = join_tokens(seq) |> normalize_tokens()
      struct = update_entries(key, value, struct)

      cond do
        check?(rest, :eol) ->
          consume(rest, 1) |> parse_root(struct)

        true ->
          rest =
            expect!(rest, ",")
            |> expect!(:whitespace)

          parse_inline_dict(rest, struct)
      end
    end
  end

  def parse_vector(tokens, struct) do
    [{_, _, first}, {_, _, second}, _rest] = tokens

    cond do
      first == :colon && second == :colon ->
        # multiline dict
        nil

      first == :colon && second != :colon ->
        # inline dict
        nil
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
