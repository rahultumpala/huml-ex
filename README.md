# huml-ex
Elixir support for HUML markup

This library implements the HUML [v0.1.0](https://huml.io/specifications/v0-1-0) and HUML [v0.2.0](https://huml.io/specifications/v0-2-0) specifications.

## Usage

The API is similar to the Jason Elixir library.

```elixir
# Successful decode
{:ok, huml_map} = HUML.decode(valid_huml_doc_str)
# Unsuccessful decode
{:error, message} = HUML.decode(invalid_huml_doc_str)
# Successful encode
{:ok, encoded_str} = HUML.encode(huml_map)
```

- A dictionary item in the doc is reprsented as an Elixir Map struct
- A List item is represented as an Elixir List struct
- `nan`          --> `:nan`
- `inf` , `+inf` --> `:infinity`
- `-inf`         --> `:neg_infinity`
- `null`         --> `nil`
- `false` and `true` are same as Elixir's built in boolean types

## Example

An Example of a complex HUML definition parsed into an Elixir Map.

```elixir
test_huml = """
foo_final::
  # Final complex test structure
  foo_final_test::
    bar_everything::
      - ::
        string_val: "test"
        int_val: 42
        float_val: 3.14
        bool_val: true
        null_val: null
        inline_list:: 1, "two", 3.0, true, null
        inline_dict:: key: "value", num: 123
        nested_dict::
          deep_key: "deep_value"
          deep_list::
            - "item1"
            - :: nested: "item"
            - "item3"
      - "simple_string_item"
      - 999
      - ::
        final_nested::
          ultimate_test:: success: true, complete: "yes"
"""

# HUML.decode(test_huml)
{:ok,
 %{
   "foo_final" => %{
     "foo_final_test" => %{
       "bar_everything" => [
         [
           {"string_val", "test"},
           {"null_val", nil},
           {"nested_dict",
            %{
              "deep_key" => "deep_value",
              "deep_list" => ["item1", [{"nested", "item"}], "item3"]
            }},
           {"int_val", 42},
           {"inline_list", [1, "two", 3.0, true, nil]},
           {"inline_dict", %{"key" => "value", "num" => 123}},
           {"float_val", 3.14},
           {"bool_val", true}
         ],
         "simple_string_item",
         999,
         [
           {"final_nested",
            %{"ultimate_test" => %{"complete" => "yes", "success" => true}}}
         ]
       ]
     }
   }
 }}
```

## Coverage

```
Finished in 0.3 seconds (0.00s async, 0.3s sync)
174 tests, 0 failures
```

This library uses git submodules to load [upstream tests](https://github.com/huml-lang/tests/) into the `tests` folder.

[`test_gen.exs`](./test/test_gen.exs) contains a convenient macro to auto generate ExUnit test cases from upstream test definitions.

Running `mix test` will generate tests and run the implementation against them.

## Installation

Install from git as this library is not available in Hex yet.

```elixir
# in mix.exs

defp deps do
  [{:huml, git: "https://github.com/rahultumpala/huml-ex.git"}]
end
```
