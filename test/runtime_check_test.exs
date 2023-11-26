defmodule RuntimeCheckTest do
  use ExUnit.Case
  doctest RuntimeCheck

  test "greets the world" do
    assert RuntimeCheck.hello() == :world
  end
end
