defmodule HUMLTest do
  use ExUnit.Case
  doctest HUML

  require TestGen

  TestGen.generate_tests(__ENV__)

  test "greets the world" do
    assert HUML.hello() == :i_am_huml
  end
end
