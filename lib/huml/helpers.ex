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

  def read_until(tokens, match_tokens) do
    Enum.split_while(tokens, fn {_line, _col, tok} -> !(tok in match_tokens) end)
  end

  def read_value(tokens) do
    cond do
      check?(tokens, "\"") ->
        [cur | rest] = tokens
        {seq, [d_quote | rest]} = rest |> read_until(["\""])
        # join beginning and ending double quotes to the seq before normalizing.
        {[cur] ++ seq ++ [d_quote], rest}

      true ->
        tokens |> read_until([:colon, :whitespace, ",", :eol])
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
    num_with_exp_rgx = ~r/^(?<value>(\+|-)?([0-9])+(\.([0-9])+)?(e(\+|-)?([0-9])+))$/
    num_rgx = ~r/^(?<value>(\+|-)?([0-9])+(\.([0-9])*)?)$/
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

  def update_entries(struct, tokens) do
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
    state = Map.get(struct, :entries, %{})

    cond do
      is_list(state) ->
        raise Huml.ParseError,
          message:
            "The document is already evaluated to be a list. Further nesting is not allowed. Check the doc."

      is_map(state) ->
        Map.put(struct, :entries, Map.put(state, key, value))
    end
  end
end
