defmodule HUML do
  @moduledoc """
  Documentation for `HUML`.
  """

  import Huml.{Vsn, Helpers, Tokenizer, Root}

  def decode(str) do
    try do
      tokens = tokenize(str)

      if length(tokens) == 0 do
        {:error, "Empty document."}
      else
        reject!(tokens, :whitespace)
        {:ok, parse(tokens)}
      end
    rescue
      e -> {:error, e}
    end
  end

  def parse(tokens) do
    {tokens, struct} = parse_vsn(tokens)
    {struct, []} = parse_root(tokens, struct)

    entries = Map.get(struct, :entries, [])

    cond do
      entries == [] && Map.has_key?(struct, :version) ->
        raise Huml.ParseError, message: "Doc has only version. No entries. Invalid doc."

      true ->
        entries
    end
  end

  def encode(entry) do
    {:ok, encode(entry, 0) <> "\n"}
  end

  @spec encode(term(), number()) :: binary()
  defp encode(entry, indent) when is_list(entry) do
    length = Enum.count(entry)

    encoded =
      entry
      |> Enum.with_index()
      |> Enum.reduce("", fn {value, index}, r_acc ->
        r_acc
        |> Kernel.<>(String.duplicate(" ", indent))
        |> Kernel.<>("- ")
        |> Kernel.<>(
          cond do
            is_list(value) ->
              "::\n" <> encode(value, indent + 2)

            is_map(value) ->
              "::\n" <> encode(value, indent + 4)

            is_tuple(value) ->
              encode(value, indent)

            true ->
              encode_terminal(value, indent)
          end
        )
        |> Kernel.<>(
          cond do
            index < length - 1 -> "\n"
            true -> ""
          end
        )
      end)

    encoded
  end

  defp encode(entry, indent) when is_map(entry) do
    length = Enum.count(entry)

    encoded =
      entry
      |> Enum.map(fn {key, value} -> {key, value} end)
      |> Enum.with_index()
      |> Enum.reduce("", fn {{key, value}, index}, r_acc ->
        r_acc
        |> Kernel.<>(String.duplicate(" ", indent))
        |> Kernel.<>(encode_terminal(key, indent))
        |> Kernel.<>(
          cond do
            is_list(value) ->
              "::\n" <> encode(value, indent + 2)

            is_map(value) ->
              "::\n" <> encode(value, indent + 2)

            true ->
              ": " <> encode_terminal(value, indent)
          end
        )
        |> Kernel.<>(
          cond do
            index < length - 1 -> "\n"
            true -> ""
          end
        )
      end)

    encoded
  end

  defp encode({key, value} = entry, indent) when is_tuple(entry) do
    encoded =
      ""
      |> Kernel.<>(encode_terminal(key, indent))
      |> Kernel.<>(
        cond do
          is_list(value) ->
            "::\n" <> encode(value, indent + 2)

          is_map(value) ->
            "::\n" <> encode(value, indent + 4)

          true ->
            ": " <> encode_terminal(value, indent + 2)
        end
      )

    encoded
  end

  defp encode_terminal(entry, indent) do
    cond do
      entry == nil ->
        "null"

      is_binary(entry) && is_string_multiline?(entry) ->
        "\"\"\"\n"
        |> then(fn t_acc ->
          t_acc <>
            (String.split(entry, "\n")
             |> Enum.reduce("", fn line, acc ->
               cond do
                 String.length(line) > 0 ->
                   acc <> String.duplicate(" ", indent + 2) <> line <> "\n"

                 true ->
                   acc <> line
               end
             end))
        end)
        |> Kernel.<>(String.duplicate(" ", indent))
        |> Kernel.<>("\"\"\"")

      is_binary(entry) ->
        "\"" <> to_string(entry) <> "\""

      entry == :infinity ->
        "+inf"

      entry == :neg_infinity ->
        "-inf"

      entry == :nan ->
        "nan"

      true ->
        to_string(entry)
    end
  end
end
