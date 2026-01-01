# huml-ex
Elixir support for HUML markup

This library implements the HUML [v0.1.0](https://huml.io/specifications/v0-1-0) and HUML [v0.2.0](https://huml.io/specifications/v0-2-0) specifications.

## Usage

The API is similar to the Jason Elixir library.

```elixir
# HUML.decode/1

{:ok, doc} = HUML.decode(valid_huml_doc_str)

{:error, message} = HUML.decode(invalid_huml_doc_str)
```

- A dictionary item in the doc is reprsented as an Elixir Map struct
- A List item is represented as an Elixir List struct
- `nan`          --> `:nan`
- `inf` , `+inf` --> `:infinity`
- `-inf`         --> `:neg_infinity`
- `null`         --> `nil`
- `false` and `true` are same as Elixir's in-built boolean types

## Coverage

```
Finished in 0.3 seconds (0.00s async, 0.3s sync)
174 tests, 0 failures
```

This library uses git submodules to load upstream tests into the [tests](./tests/) folder.

[`test_gen.exs`](./test/test_gen.exs) contains a convenient macro to auto generate ExUnit test cases from upstream test definitions.

Running `mix test` will generate tests and run the implementation against them.

## Installation

Not available in hex yet.