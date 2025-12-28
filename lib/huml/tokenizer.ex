defmodule Huml.Tokenizer do
  @pound "#"

  def tokenize(str) do
    str
    |> String.split("\n")
    |> Enum.with_index(fn el, idx -> {idx, el} end)
    |> Enum.map(fn {line, content} ->
      cols =
        content
        |> String.codepoints()
        |> Enum.with_index(fn el, idx -> {idx, el} end)
        |> Enum.map(fn {col, char} -> {line, col, char} end)

      cols ++ [{line, String.length(content), :eol}]
    end)
    |> Enum.filter(fn token_line ->
      # remove all lines that being with a pound sign. These are all comments and can be ignored.
      with true <- length(token_line) > 0,
           {_line, _col, char} <- Enum.at(token_line, 0),
           true <- char != @pound do
        true
      else
        _ -> false
      end
    end)
    |> Enum.concat()
    |> Enum.map(fn {line, col, char} ->
      char =
        case char do
          "\n" ->
            :newline

          " " ->
            :whitespace

          "\"" ->
            :quote

          "`" ->
            :backtick

          ":" ->
            :colon

          "[" ->
            :square_bracket_open

          "]" ->
            :square_bracket_close

          "{" ->
            :curly_bracket_open

          "}" ->
            :curly_bracket_close

          _ ->
            char
        end

      {line, col, char}
    end)
  end
end
