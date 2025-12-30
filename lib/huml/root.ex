defmodule Huml.Root do
  import Huml.{Helpers}

  def parse_root([], struct) do
    {struct, []}
  end

  def parse_root([cur | _rest] = tokens, struct) do
    {struct, rest} =
      case cur do
        {_, _, :eol} ->
          consume(tokens, 1) |> parse_root(struct)

        {_line, _col, :square_bracket_open} ->
          parse_empty_list(struct, tokens)

        {_line, _col, :curly_bracket_open} ->
          parse_empty_dict(struct, tokens)

        {_, _, :indent} ->
          # this path must be from parsing multiline vectors. Return as is to resume parsing there.
          parse_multiline_vector(tokens, struct)

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
                        [join_tokens(next_seq) |> normalize_tokens()] ++ val
                      end)

                    rest |> consume(1) |> parse_root(struct)
                end

              {line, col, :whitespace} ->
                raise Huml.ParseError,
                  message: "Unexpected whitespace at line:#{line} col:#{col}."
            end

          {struct, rest}
      end

    parse_root(rest, struct)
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
        struct = struct |> update_entries(seq)
        parse_inline_list(rest, struct)
    end
  end

  defp parse_inline_dict([], struct) do
    {struct, []}
  end

  defp parse_inline_dict(tokens, struct) do
    {seq, rest} = read_until(tokens, [:colon, :eol])

    if length(seq) == 0 do
      {struct, rest}
    else
      key = join_tokens(seq) |> normalize_tokens(:dict_key)

      rest =
        expect!(rest, :colon)
        |> expect!(:whitespace)

      {seq, rest} = read_value(rest)
      value = join_tokens(seq) |> normalize_tokens()
      struct = struct |> update_entries(key, value)

      cond do
        check?(rest, :eol) ->
          rest = consume(rest, 1)
          {struct, rest}

        true ->
          rest =
            expect!(rest, ",")
            |> expect!(:whitespace)

          parse_inline_dict(rest, struct)
      end
    end
  end

  def parse_vector(tokens, struct) do
    # read both colon values
    {seq, rest} = read_until(tokens, [:colon])

    rest =
      rest
      |> expect!(:colon)
      |> expect!(:colon)

    cond do
      check?(rest, :eol) ->
        # multiline dict
        {children, rest} =
          rest
          |> expect!(:eol)
          |> parse_multiline_vector(%{})

        key = join_tokens(seq) |> normalize_tokens(:dict_key)
        struct = update_entries(struct, key, Map.get(children, :entries, %{}))
        {struct, rest}

      check?(rest, :whitespace) ->
        # inline dict
        key = join_tokens(seq) |> normalize_tokens(:dict_key)
        {value, rest} = parse_inline_dict(rest, %{})
        struct = update_entries(struct, key, Map.get(value, :entries, %{}))

        {struct, rest}
    end
  end

  defp parse_multiline_vector(tokens, struct) do
    tokens = tokens |> expect!(:indent)

    cond do
      check?(tokens, "-") ->
        {struct, rest} = tokens |> expect!(:whitespace) |> parse_root(struct)
        {struct, rest}

      true ->
        tokens |> parse_root(struct)
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
