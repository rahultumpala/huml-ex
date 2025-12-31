defmodule TestGen do
  defmacro generate_tests(_env) do
    json_txt =
      case File.read("tests/assertions/mixed.json") do
        {:ok, txt} ->
          txt

        _ ->
          throw(
            "Could not read assertions file: tests/assertions/mixed.json. Did you git init submodule?"
          )
      end

    tests =
      json_txt
      |> Jason.decode!()
      |> Enum.with_index()
      |> Enum.map(fn {assertion, idx} ->
        name = "#{Map.get(assertion, "name")} (#{idx})"
        input = Map.get(assertion, "input")
        error = Map.get(assertion, "error")

        quote do
          test unquote(name) do
            IO.puts("Running Test #{unquote(name)}")

            case HUML.decode(unquote(input)) do
              {:error, msg} ->
                if true != unquote(error) do
                  {unquote(input), msg} |> dbg
                end

                assert true == unquote(error)

              {:ok, struct} ->
                if false != unquote(error) do
                  struct |> dbg
                  {unquote(input)} |> dbg
                end

                assert false == unquote(error)
            end
          end
        end
      end)

    quote do
      (unquote_splicing(tests))
    end
  end
end
