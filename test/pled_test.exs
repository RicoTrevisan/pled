defmodule PledTest do
  use ExUnit.Case
  doctest Pled

  test "greets the world" do
    assert Pled.hello() == :world
  end
end
