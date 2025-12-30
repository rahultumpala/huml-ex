defmodule Huml.Helpers do
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

  def reject!({line, col, char} = cur, token) do
    if check?(cur, token) do
      raise Huml.ParseError,
        message: "Did not expect #{char} at line:#{line} col:#{col}"
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

  def join_tokens(tokens) do
    Enum.reduce(tokens, "", fn {_line, _col, tok}, acc ->
      case tok do
        :whitespace -> acc <> " "
        :eol -> acc
        _ -> acc <> tok
      end
    end)
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
        {seq, [d_quote | rest]} = rest |> read_until(["\""], true)
        # join beginning and ending double quotes to the seq before normalizing.
        {[cur] ++ seq ++ [d_quote], rest}

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
    string_rgx = ~r/^"(?<value>(\\\"|[^"\n])*)"$/
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
          num_with_exp_rgx,
          num_rgx,
          hexadecimal_rgx,
          octal_rgx,
          binary_rgx,
          nan,
          inf
        ]
      end

    {:ok, value} =
      Enum.map(regexes, &match_regex_and_length(&1, joined))
      |> Enum.filter(fn {status, _content} -> status == :ok end)
      |> Enum.at(0, {:ok, nil})

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

    cond do
      is_map(state) ->
        raise Huml.ParseError,
          message:
            "The document is already evaluated to be a dict. Adding inline lists is not allowed. Check the doc."

      is_list(state) ->
        Map.put(struct, :entries, [join_tokens(tokens) |> normalize_tokens()] ++ state)
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
end
