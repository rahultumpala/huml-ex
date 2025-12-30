defmodule Huml.Root do
  import Huml.{Helpers}

  @t_depth "__token_depth__"

  def parse_root([], struct) do
    {struct, []}
  end

  def parse_root(tokens, struct) do
    expected_depth = get_d(struct, @t_depth)

    if !check_indents?(tokens, expected_depth) do
      {struct, tokens}
    else
      tokens = expect_indents!(tokens, expected_depth)
      {struct, rest} = parse_tokens(tokens, struct)

      parse_root(rest, struct)
    end
  end

  def parse_tokens([cur | _rest] = tokens, struct) do
    case cur do
      {_, _, "-"} ->
        tokens |> parse_multiline_vector(struct)

      {_line, _col, :square_bracket_open} ->
        parse_empty_list(tokens, struct)

      {_line, _col, :curly_bracket_open} ->
        parse_empty_dict(tokens, struct)

      _ ->
        {cur_seq, rest} = read_value(tokens)

        join_tokens(cur_seq)

        [first | rest] = rest

        {struct, rest} =
          case first do
            {_, _, :colon} ->
              [second | _rest] = rest

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
                length(cur_seq) == 0 ->
                  {struct, tokens |> consume(1)}

                length(cur_seq) > 0 ->
                  struct = struct |> update_entries(cur_seq)

                  {struct, rest}
              end

            {line, col, :whitespace} ->
              {seq, _rest} = read_until(tokens, [:eol])

              raise Huml.ParseError,
                message:
                  "Unexpected whitespace at line:#{line} col:#{col} in content '#{join_tokens(seq)}.'}"
          end

        {struct, rest}
    end
  end

  defp parse_inline_vector(tokens, struct) do
    [{_, _, first} | _rest] = tokens

    case first do
      :square_bracket_open ->
        parse_empty_list(tokens, struct)

      :curly_bracket_open ->
        parse_empty_dict(tokens, struct)

      _ ->
        # could be either inline list or inline dict.
        {seq, rest} = read_value(tokens)

        case rest do
          [] ->
            update_entries(struct, seq)

          [{line, col, tok} | _rest] ->
            case tok do
              "," ->
                parse_inline_list(tokens, struct)

              :colon ->
                parse_inline_dict(tokens, struct)

              _ ->
                raise Huml.ParseError,
                  message:
                    "Expected a comma or a colon after element at line:#{line} col:#{col} but found '#{tok |> to_string()}' after element '#{join_tokens(seq) |> to_string}'."
            end
        end
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
        struct = struct |> update_entries(seq)
        parse_inline_list(rest, struct)
    end
  end

  defp parse_inline_dict([], struct) do
    {struct, []}
  end

  defp parse_inline_dict(tokens, struct) do
    {seq, rest} = read_value(tokens)

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
          |> parse_root(new_struct(struct))

        if seq == [] do
          struct = add_children(struct, children)
          {struct, rest}
        else
          key = join_tokens(seq) |> normalize_tokens(:dict_key)

          # reverse to maintain list order defined in the file
          children = Map.get(children, :entries, [])

          struct = update_entries(struct, key, children)
          {struct, rest}
        end

      check?(rest, :whitespace) ->
        # inline dict or inline list
        {value, rest} = rest |> consume(1) |> parse_inline_vector(%{})

        if seq == [] do
          struct = add_children(struct, value)
          {struct, rest}
        else
          key = join_tokens(seq) |> normalize_tokens(:dict_key)
          struct = update_entries(struct, key, Map.get(value, :entries, %{}))
          {struct, rest}
        end
    end
  end

  defp parse_multiline_vector(tokens, struct) do
    cond do
      # multiline list
      check?(tokens, "-") ->
        tokens =
          tokens
          |> expect!("-")
          |> expect!(:whitespace)

        cond do
          check?(tokens, :colon) ->
            {children, rest} =
              parse_vector(tokens, struct)

            struct = add_children(struct, children)
            {struct, rest}

          true ->
            tokens |> parse_tokens(struct)
        end

      true ->
        [{line, _, _} | _rest] = tokens
        {seq, _rest} = read_until(tokens, [:eol])

        raise Huml.ParseError,
          message:
            "Expected a multiline list or multiline dict at line:#{line} but got '#{join_tokens(seq)}'¸"
    end
  end

  defp parse_empty_list(tokens, struct) do
    tokens =
      tokens
      |> expect!(:square_bracket_open)
      |> expect!(:square_bracket_close)
      |> expect!(:eol)

    struct = struct |> Map.put(:entries, [])

    {struct, tokens}
  end

  defp parse_empty_dict(tokens, struct) do
    tokens =
      tokens
      |> expect!(:curly_bracket_open)
      |> expect!(:curly_bracket_close)
      |> expect!(:eol)

    struct = struct |> Map.put(:entries, %{})

    {struct, tokens}
  end

  def new_struct(struct) do
    %{}
    |> Map.put(@t_depth, get_d(struct, @t_depth) + 1)
  end
end
