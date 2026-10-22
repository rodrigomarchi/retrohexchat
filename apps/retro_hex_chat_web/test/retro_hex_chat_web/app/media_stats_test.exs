defmodule RetroHexChatWeb.App.MediaStatsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChatWeb.App.{GroupCallStats, MediaStats, P2PStats}

  test "reads string and atom keys alike, and fills what is missing" do
    assert %{rtt_ms: 40, mos: 4, level: "excellent"} =
             MediaStats.connection(%{"rtt_ms" => 40, mos: 4})
  end

  test "an unknown key creates no atom and falls back to the default" do
    assert MediaStats.value(%{}, "no_such_key_#{System.unique_integer()}", :default) == :default
    assert MediaStats.value(:not_a_map, "fps", 0) == 0
  end

  test "a P2P sample that is not a map still gives a complete struct" do
    assert P2PStats.normalize(nil) == P2PStats.empty()

    assert %{video: %{source: "screen"}} =
             P2PStats.normalize(%{"video" => %{"source" => "screen"}})
  end

  test "a group call's empty struct is what an empty sample normalizes to" do
    assert GroupCallStats.normalize(%{}) == GroupCallStats.empty()
    assert %{audio: %{in_kbps: 12}} = GroupCallStats.normalize(%{audio: %{in_kbps: 12}})
  end
end
