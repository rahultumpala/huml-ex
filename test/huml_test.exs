defmodule HUMLTest do
  use ExUnit.Case
  doctest HUML

  require TestGen

  ## Generates tests and asserts on the output based on the tests defined in tests/assertions/mixed.json
  TestGen.generate_tests(__ENV__)

  ## Assert that tests/documents/mixed.huml parses correctly into the structure defined in tests/documents/mixed.json
  test "structure verification from mixed.huml" do
    huml_doc = File.read!("tests/documents/mixed.huml") |> HUML.decode()
  end
end
