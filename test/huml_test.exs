defmodule HUMLTest do
  use ExUnit.Case
  doctest HUML

  test "greets the world" do
    assert HUML.hello() == :i_am_huml
  end

  test "parse1" do
    txt = """
    %HUML v0.1.0

    "foo"
    simple_key
    1.234
    +3.12e+123
    0xAF
    0b00010
    0o31
    nan
    inf
    """
    # HUML.decode(txt)
    assert true
  end

  test "parse" do
    txt = """
    # Kitchensink test file.
    foo_one:: # Hello
      # Scalar values testing - basic types
      foo_string: "bar_value"
      bar_string: "baz with spaces"
      baz_int: 42
      qux_float: 3.14159
      quux_bool: true
      corge_bool: false
      grault_null: null
    """
    HUML.decode(txt)
    assert true
  end
end
