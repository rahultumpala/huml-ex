defmodule HUMLTest do
  use ExUnit.Case
  doctest HUML

  test "greets the world" do
    assert HUML.hello() == :world
  end
end
