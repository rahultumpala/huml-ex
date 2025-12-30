defmodule Huml.Tokenizer do
  import Huml.Helpers

  def tokenize(str) do
    str
    |> String.split("\n")
    # 1 based indexing
    |> Enum.with_index(fn el, idx -> {idx + 1, el} end)
    |> Enum.map(&remove_trailing/1)
    |> Enum.map(fn {line, content} ->
      cols =
        content
        |> String.codepoints()
        # 1 based indexing
        |> Enum.with_index(fn el, idx -> {idx + 1, el} end)
        |> Enum.map(fn {col, char} -> {line, col, char} end)

      cols ++ [{line, String.length(content), :eol}]
    end)
    |> Enum.filter(fn token_line ->
      # discard empty lines
      # discard lines that being with a pound sign. These are all comments and can be ignored.
      with true <- length(token_line) > 0,
           str <- join_tokens(token_line) |> String.trim(),
           true <- String.length(str) > 0 && String.starts_with?(str, "#") do
        false
      else
        _ -> true
      end
    end)
    |> Enum.map(&tokenize_char/1)
    |> Enum.map(&add_indent/1)
    |> Enum.concat()
  end

  def add_indent(line) do
    {spaces, rest} = Enum.split_while(line, fn {_, _, tok} -> tok == :whitespace end)
    len = length(spaces)

    indent_tokens =
      cond do
        len == 0 ->
          []

        Kernel.rem(len, 2) != 0 ->
          [{line, _, _} | _rest] = spaces
          raise Huml.ParseError, message: "Invalid indentation on line:#{line}."

        len > 0 ->
          num = Kernel.div(len, 2)
          [{line, _, _} | _rest] = spaces
          Enum.map(1..num, fn col -> {line, col, :indent} end)
      end

    indent_tokens ++ rest
  end

  def tokenize_char(token_line) do
    token_line
    |> Enum.map(fn {line, col, char} ->
      char =
        case char do
          "\n" ->
            :newline

          " " ->
            :whitespace

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

  def remove_trailing({line_num, str}) do
    # remove trailing comments
    # report trailing spaces
    comment_rgx = ~r/(?<comment>(([ ])+# .*$))/
    trailing_spaces_rgx = ~r/(?<spaces>([ ])+$)/

    str =
      cond do
        Regex.match?(comment_rgx, str) ->
          match = Regex.named_captures(comment_rgx, str) |> Map.get("comment")

          # delete trailing comments
          String.replace(str, match, "")

        true ->
          str
      end

    str =
      cond do
        Regex.match?(trailing_spaces_rgx, str) ->
          len =
            Regex.named_captures(trailing_spaces_rgx, str) |> Map.get("spaces") |> String.length()

          raise Huml.ParseError,
            message: "#{len} Trailing spaces found on line:#{line_num}. \nLine Content: #{str}"

        true ->
          str
      end

    {line_num, str}
  end
end
