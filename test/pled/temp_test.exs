defmodule Pled.TempTest do
  use ExUnit.Case, async: true

  @tag :tmp_dir
  test "test tmp_dir", %{tmp_dir: tmp_dir} do
    dbg(tmp_dir)
  end
end
