defmodule HUMLTest do
  use ExUnit.Case
  doctest HUML

  require TestGen

  TestGen.generate_tests(__ENV__)
end
