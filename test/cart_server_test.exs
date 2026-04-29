defmodule CartServerTest do
  use ExUnit.Case
  doctest CartServer

  test "greets the world" do
    assert CartServer.hello() == :world
  end
end
