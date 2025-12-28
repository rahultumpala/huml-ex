defmodule Huml.Helpers do
  def check?({_line, _col, char}, token) do
    char == token
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
end
