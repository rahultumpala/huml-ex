defmodule Huml.Vsn do
  import Huml.{Helpers}

  @vsn_regex ~r/^%HUML (?<vsn>([a-zA-Z]|[0-9]|.|_|-)+)$/
  @percent "%"

  @doc "Parses version string from first line. Returns tuple: {struct, rest}"
  def parse_vsn([{_line, col, _tok} | _rest] = tokens) do
    {line, rest} = read_line(tokens)

    case line do
      [] ->
        parse_vsn(rest)

      [_cur | _rest] ->
        with true <- check?(Enum.at(line, 0), @percent),
             content <- join_tokens(line) do
          case read_vsn(content) do
            {:ok, vsn} ->
              read_vsn(content)
              {rest, %{version: vsn}}

            {:error, :no_vsn} ->
              raise Huml.ParseError,
                message:
                  "Expected valid version definition at line:#{line} col:#{col}. Receivied #{content}"
          end
        else
          _ ->
            # return all tokens as version was not found.
            {tokens, %{}}
        end
    end
  end

  @doc "Reads version from the lines. Returns a tuple {struct, lines}"
  def read_vsn(content) do
    with true <- Regex.match?(@vsn_regex, content),
         named_captures <- Regex.named_captures(@vsn_regex, content),
         vsn <- Map.get(named_captures, "vsn", nil),
         true <- vsn != nil && String.length(vsn) > 0 do
      {:ok, vsn}
    else
      _ -> {:error, :no_vsn}
    end
  end
end
