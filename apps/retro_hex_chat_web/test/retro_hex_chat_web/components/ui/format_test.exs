defmodule RetroHexChatWeb.Components.UI.FormatTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChatWeb.Components.UI.Format

  describe "bytes/1" do
    test "leaves small counts in bytes, unrounded" do
      assert Format.bytes(0) == "0 B"
      assert Format.bytes(1) == "1 B"
      assert Format.bytes(1023) == "1023 B"
    end

    test "climbs a unit at each boundary" do
      assert Format.bytes(1024) == "1 KB"
      assert Format.bytes(1_048_576) == "1 MB"
      assert Format.bytes(1_073_741_824) == "1 GB"
    end

    test "carries one decimal where it says something" do
      assert Format.bytes(1536) == "1.5 KB"
      assert Format.bytes(1_572_864) == "1.5 MB"
      assert Format.bytes(1_610_612_736) == "1.5 GB"
    end

    test "drops a decimal that is only a zero" do
      assert Format.bytes(2048) == "2 KB"
      assert Format.bytes(2_097_152) == "2 MB"
    end

    test "keeps a large count readable instead of exponential" do
      assert Format.bytes(107_374_182_400) == "100 GB"
      refute Format.bytes(107_374_182_400) =~ "e"
    end

    test "says nothing rather than zero when the size is unknown" do
      assert Format.bytes(nil) == "—"
      assert Format.bytes("2048") == "—"
      assert Format.bytes(2048.0) == "—"
    end
  end
end
