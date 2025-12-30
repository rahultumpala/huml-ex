defmodule HUMLTest do
  use ExUnit.Case
  doctest HUML

  test "greets the world" do
    assert HUML.hello() == :i_am_huml
  end

  test "simple" do
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

  test "inline_list" do
    txt = """
    %HUML v0.1.0

    "foo", simple_key, 1.234
    """

    # HUML.decode(txt)
    assert true
  end

  test "inline dict" do
    txt = """
    %HUML v0.1.0

    "foo": "bar", simple_key: 1.234
    """

    # HUML.decode(txt)
    assert true
  end

  test "multiline_dict" do
    txt = """
    # Kitchensink test file.
    foo_one:: # Hello
      # Scalar values testing - basic types
      foo_string: "bar_value"
    """

    # HUML.decode(txt)
    assert true
  end

  test "list variations" do
    txt = """
    # List variations
    data_sources::
      - "primary_db_connection_string"
      - "secondary_api_endpoint_url"
      - "192.168.1.100" # IP address as a string
      - :: # A list of lists
        - "alpha"
        - "beta"
        - "gamma"
      - true # A boolean in a list
    """
    # HUML.decode(txt)
    assert true
  end

  test "complex" do
    txt = """
    %HUML v0.1.0

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

    # inline collections
    inline_collections::
      simple_list:: "red", "green", "blue"
      simple_dict:: color: "yellow", intensity: 0.8, transparent: false

    # List variations
    data_sources::
      - "primary_db_connection_string"
      - "secondary_api_endpoint_url"
      - "192.168.1.100" # IP address as a string
      - :: # A list of lists
        - "alpha"
        - "beta"
        - "gamma"
      - true # A boolean in a list
    """

    HUML.decode(txt)
    assert true
  end
end
