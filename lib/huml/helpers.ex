defmodule Huml.Helpers do
  def check_multiline_str_start?(tokens) do
    {match, _rest} = read_until_sequence(tokens, ["\"", "\"", "\"", :eol])
    length(match) == 4
  end

  def check?(tokens, token) when is_list(tokens) do
    [cur | _rest] = tokens
    check?(cur, token)
  end

  def check?({_line, _col, char}, token) do
    char == token
  end

  def expect!(tokens, token) when is_list(tokens) do
    # matches and consumes the first token. returns the rest
    [cur | rest] = tokens
    expect!(cur, token)
    rest
  end

  def expect!({line, col, char} = cur, token) do
    if !check?(cur, token) do
      raise Huml.ParseError,
        message: "Expected #{token} but received #{char} at line:#{line} col:#{col}"
    end
  end

  def reject!([{line, col, char} = cur | _rest], token) do
    if check?(cur, token) do
      raise Huml.ParseError,
        message: "Unexpected '#{char}' at line:#{line} col:#{col}"
    end
  end

  def read_line([]) do
    []
  end

  def read_line(tokens) when is_list(tokens) do
    read_line(tokens, [])
  end

  def read_line([{_, _, tok} = cur | rest], acc) do
    case tok do
      :eol -> {Enum.reverse([cur | acc]), rest}
      _ -> read_line(rest, [cur | acc])
    end
  end

  def join_regular_tokens(tokens, raise_eol? \\ false) do
    # dbg(tokens)
    Enum.reduce(tokens, "", fn {line, col, tok}, acc ->
      case tok do
        :whitespace ->
          acc <> " "

        :eol ->
          if raise_eol? do
            raise Huml.ParseError,
              message: "Found unexpected newline character at line:#{line} col:#{col}."
          else
            acc <> "\n"
          end

        _ ->
          acc <> tok
      end
    end)
  end

  def join_tokens(tokens, remove_prefix_indent \\ 0) do
    [{_, _, cur} | _rest] = tokens

    case cur do
      "\"" ->
        cond do
          check_multiline_str_start?(tokens) ->
            parse_multiline_string(tokens, "", false, remove_prefix_indent)

          true ->
            join_regular_tokens(tokens, true)
        end

      "`" ->
        parse_multiline_string(tokens, "", true, remove_prefix_indent)

      _ ->
        join_regular_tokens(tokens)
    end
  end

  def read_until([], _prev, _match_tokens, acc) do
    {acc, []}
  end

  def read_until([{_, _, tok} = cur | rest] = tokens, prev, match_tokens, acc) do
    cond do
      prev == "\\" || !(tok in match_tokens) -> read_until(rest, tok, match_tokens, acc ++ [cur])
      tok in match_tokens -> {acc, tokens}
    end
  end

  def read_until(tokens, match_tokens, inside_string? \\ false) do
    {match, no_match} = read_until(tokens, nil, match_tokens, [])

    match =
      Enum.map(match, fn {line, col, tok} ->
        cond do
          tok == :colon && inside_string? -> {line, col, ":"}
          true -> {line, col, tok}
        end
      end)

    {match, no_match}
  end

  def count_while(tokens, match_tokens) do
    {match, _no_match} =
      Enum.split_while(tokens, fn {_line, _col, tok} -> tok in match_tokens end)

    length(match)
  end

  def read_value(tokens, match_tokens \\ [:colon, :whitespace, ",", :eol]) do
    cond do
      check?(tokens, "\"") ->
        [cur | rest] = tokens

        if check_multiline_str_start?(tokens) do
          read_multiline_string(tokens, false)
        else
          {seq, [d_quote | rest]} = rest |> read_until(["\""], true)
          # join beginning and ending double quotes to the seq before normalizing.
          {[cur] ++ seq ++ [d_quote], rest}
        end

      check?(tokens, "`") ->
        read_multiline_string(tokens, true)

      true ->
        tokens |> read_until(match_tokens)
    end
  end

  def consume(tokens, num) do
    {_discard, rest} = Enum.split(tokens, num)
    rest
  end

  def normalize_tokens(joined) do
    # this is for joining all terminal values
    normalize_tokens(joined, nil)
  end

  def normalize_tokens(joined, type) do
    multiline_string_with_spaces_rgx = ~r/^```\n(?<value>(.*\n)*)([ ])*```\n$/
    multiline_string_without_spaces_rgx = ~r/^\"\"\"\n(?<value>(.*\n)*)([ ])*\"\"\"\n$/
    string_rgx = ~r/^"(?<value>(\\\"|[^"(\\\n)\n])*)"$/
    dict_key_rgx = ~r/^(?<value>^[a-zA-Z]([a-z]|[A-Z]|[0-9]|-|_)*)$/
    num_with_exp_rgx = ~r/^(?<value>(\+|-)?([0-9]|)+(\.([0-9])+)?(e(\+|-)?([0-9])+))$/
    num_rgx = ~r/^(?<value>(\+|-)?([0-9_])+(\.([0-9])*)?)$/
    hexadecimal_rgx = ~r/^(?<value>(\+|-)?0x([0-9]|[A-F])+)$/
    octal_rgx = ~r/^(?<value>(\+|-)?0o([0-7])+)$/
    binary_rgx = ~r/^(?<value>(\+|-)?0b([0-1])+)$/
    nan = ~r/^(?<value>nan)$/
    inf = ~r/^(?<value>(\+|-)?inf)$/

    regexes =
      if type == :dict_key do
        [
          string_rgx,
          dict_key_rgx
        ]
      else
        [
          string_rgx,
          dict_key_rgx,
          nan,
          inf,
          multiline_string_with_spaces_rgx,
          multiline_string_without_spaces_rgx
        ]
      end

    number_regexes = [
      num_with_exp_rgx,
      num_rgx,
      hexadecimal_rgx,
      octal_rgx,
      binary_rgx
    ]

    {:ok, value} =
      Enum.map(regexes, &match_regex_and_length(&1, joined))
      |> Enum.filter(fn {status, _content} -> status == :ok end)
      |> Enum.at(0, {:ok, nil})

    value =
      if value != nil do
        value
      else
        {:ok, value} =
          Enum.map(number_regexes, &match_regex_and_length(&1, joined))
          |> Enum.filter(fn {status, _content} -> status == :ok end)
          |> Enum.at(0, {:ok, nil})

        cond do
          value == nil -> nil
          true -> {:number, value}
        end
      end

    case value do
      nil ->
        raise Huml.ParseError,
          message: "Expected a valid sequence of characters. Got: #{joined}"

      "+inf" ->
        :infinity

      "inf" ->
        :infinity

      "-inf" ->
        :neg_infinity

      "nan" ->
        :nan

      "true" ->
        true

      "false" ->
        false

      "null" ->
        nil

      {:number, string} ->
        string = string |> String.replace("_", "")

        parsed_num =
          case String.downcase(string) do
            "0b" <> rest ->
              Integer.parse(rest, 2)

            "0o" <> rest ->
              Integer.parse(rest, 8)

            "0x" <> rest ->
              Integer.parse(rest, 16)

            _ ->
              case Integer.parse(string) do
                {int, ""} ->
                  {int, ""}

                _ ->
                  case Float.parse(string) do
                    {float, ""} -> {float, ""}
                    _ -> {:error, "Unable to parse #{string} as number."}
                  end
              end
          end

        case parsed_num do
          {num, ""} -> num
          {:error, message} -> raise Huml.ParseError, message: message
        end

      _ ->
        value
    end
  end

  def match_regex_and_length(regex, content) do
    with true <- Regex.match?(regex, content),
         value <- Regex.named_captures(regex, content) |> Map.get("value") do
      {:ok, value}
    else
      _ -> {:error, :no_match}
    end
  end

  def add_children(struct, children) do
    state = Map.get(struct, :entries, [])
    # reverse to maintain list order defined in the file
    children_list = Map.get(children, :entries, []) |> Enum.reverse()

    cond do
      is_map(state) ->
        raise Huml.ParseError,
          message:
            "The document is already evaluated to be a dict. Adding inline lists is not allowed. Check the doc."

      is_list(state) ->
        Map.put(struct, :entries, [children_list] ++ state)
    end
  end

  def update_entries(struct, tokens) do
    # matching on the shape of entries in struct, not in value
    state = Map.get(struct, :entries, [])

    value = join_tokens(tokens) |> assert_has_quotes() |> normalize_tokens()

    cond do
      is_map(state) ->
        raise Huml.ParseError,
          message:
            "The document is already evaluated to be a dict. Adding inline lists is not allowed. Check the doc."

      is_list(state) ->
        Map.put(struct, :entries, [value] ++ state)
    end
  end

  def update_entries(struct, key, value) do
    # matching on the shape of entries in struct, not in value
    state = Map.get(struct, :entries, %{})

    value =
      cond do
        is_list(value) -> Enum.reverse(value)
        true -> value
      end

    cond do
      is_list(state) ->
        raise Huml.ParseError,
          message:
            "The document is already evaluated to be a list. Further nesting is not allowed. Check the doc."

      is_map(state) ->
        if Map.has_key?(state, key) do
          raise Huml.ParseError, message: "Duplicate key '#{key}' found."
        end

        Map.put(struct, :entries, Map.put(state, key, value))
    end
  end

  def check_indents?(tokens, count) do
    {indents, _rest} = Enum.split_while(tokens, fn {_, _, tok} -> tok == :indent end)

    length(indents) == count
  end

  def expect_indents!(tokens, count) do
    {indents, rest} = Enum.split_while(tokens, fn {_, _, tok} -> tok == :indent end)

    if length(indents) != count do
      [{line, _, _} | _rest] = rest

      raise Huml.ParseError,
        message: "Expected #{count} indentations on line #{line}, got #{length(indents)}."
    end

    rest
  end

  def get_d(struct, str) do
    Map.get(struct, str, 0)
  end

  def read_multiline_string([]) do
    raise Huml.ParseError,
      message:
        "No designated ending for the multiline string. Check multiline strings in your doc."
  end

  def read_multiline_string(tokens, preserve_spaces? \\ false) do
    {string_tokens, rest} =
      case preserve_spaces? do
        false ->
          prefix = Enum.take(tokens, 4)
          tokens = tokens |> expect!("\"") |> expect!("\"") |> expect!("\"") |> expect!(:eol)
          {string_toks, rest} = read_until_sequence(tokens, ["\"", "\"", "\"", :eol])
          # not consuming so that regex can work
          {prefix ++ string_toks, rest}

        true ->
          prefix = Enum.take(tokens, 4)
          tokens = tokens |> expect!("`") |> expect!("`") |> expect!("`") |> expect!(:eol)
          {string_toks, rest} = read_until_sequence(tokens, ["`", "`", "`", :eol])
          # not consuming so that regex can work
          {prefix ++ string_toks, rest}
      end

    {string_tokens, rest}
  end

  def read_until_sequence(tokens, seq) do
    {match, _count, rest} =
      Enum.reduce(tokens, {[], 0, []}, fn {_, _, tok} = cur, {match, count, rest} ->
        cond do
          count == -1 ->
            {match, count, [cur | rest]}

          # minus 1 to account for zero based indexing
          tok == Enum.at(seq, count) && count == length(seq) - 1 ->
            {[cur | match], -1, rest}

          tok == Enum.at(seq, count) ->
            {[cur | match], count + 1, rest}

          true ->
            # reset count to maintaing sequence matching
            {[cur | match], 0, rest}
        end
      end)

    # reverse since we're adding cur at the beginning instead of the end
    {Enum.reverse(match), Enum.reverse(rest)}
  end

  def parse_multiline_string([], acc, _preserve_spaces?, _remove_prefix_indent), do: acc

  def parse_multiline_string(tokens, acc, preserve_spaces?, remove_prefix_indent) do
    {line, rest} = read_until(tokens, [:eol])

    {indents, _rest} =
      Enum.split_while(
        line,
        fn {_, _, tok} -> tok == :indent end
      )

    if preserve_spaces? && length(indents) != remove_prefix_indent do
      raise Huml.ParseError,
        message: "Expected #{remove_prefix_indent} indents but got #{length(indents)}."
    end

    with true <- Regex.match?(~r/^([ ])+"""$/, join_regular_tokens(line)),
         true <- length(indents) != remove_prefix_indent - 1 do
      raise Huml.ParseError,
        message:
          "Expected #{remove_prefix_indent - 1} indents before closing of multiline string."
    end

    line =
      Enum.reduce(line, "", fn {_, _, tok}, line_acc ->
        case tok do
          :indent ->
            line_acc <> "  "

          :colon ->
            line_acc <> ":"

          :square_bracket_open ->
            line_acc <> "["

          :square_bracket_close ->
            line_acc <> "]"

          :curly_bracket_open ->
            line_acc <> "{"

          :curly_bracket_close ->
            line_acc <> "}"

          :whitespace ->
            line_acc <> " "

          _ ->
            line_acc <> tok
        end
      end)

    # consume :eol token
    rest = rest |> consume(1)

    line =
      Regex.replace(~r/^ {#{remove_prefix_indent}}/, line, "")

    line =
      case preserve_spaces? do
        true ->
          line

        false ->
          line |> String.trim()
      end

    parse_multiline_string(rest, acc <> line <> "\n", preserve_spaces?, remove_prefix_indent)
  end

  def assert_has_quotes(value) do
    dict_key_rgx = ~r/^(?<value>^[a-zA-Z]([a-z]|[A-Z]|[0-9]|-|_)*)$/
    valid_unquoted_rgx = ~r/^(true|false|\+inf|-inf|inf|nan|null)$/

    with true <- value != nil,
         false <- is_number(value),
         false <- is_atom(value),
         true <- Regex.match?(dict_key_rgx, value),
         false <- Regex.match?(valid_unquoted_rgx, value) do
      raise Huml.ParseError, message: "Expected a quoted string but found '#{value}'."
    end

    value
  end
end
