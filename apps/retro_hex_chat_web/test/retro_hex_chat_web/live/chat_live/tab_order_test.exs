defmodule RetroHexChatWeb.ChatLive.TabOrderTest do
  use ExUnit.Case, async: true

  alias RetroHexChatWeb.ChatLive.TabOrder

  @moduletag :unit

  test "touch moves a conversation key to the front and de-duplicates it" do
    order = [{:channel, "#lobby"}, {:pm, "alice"}]

    assert TabOrder.touch(order, :pm, "alice") == [
             {:pm, "alice"},
             {:channel, "#lobby"}
           ]
  end

  test "visible_order keeps touched conversations first and appends untouched tabs" do
    order = [{:pm, "alice"}, {:channel, "#security"}]

    assert TabOrder.visible_order(["#lobby", "#security"], ["bob", "alice"], order) == [
             {:pm, "alice"},
             {:channel, "#security"},
             {:channel, "#lobby"},
             {:pm, "bob"}
           ]
  end

  test "visible_order ignores stale keys for tabs that are no longer open" do
    order = [{:pm, "closed"}, {:channel, "#security"}]

    assert TabOrder.visible_order(["#lobby"], ["alice"], order) == [
             {:channel, "#lobby"},
             {:pm, "alice"}
           ]
  end

  test "serialize and deserialize keep reconnect payloads JSON-safe" do
    order = [{:pm, "alice"}, {:channel, "#security"}]

    assert TabOrder.serialize(order) == [
             %{type: "pm", label: "alice"},
             %{type: "channel", label: "#security"}
           ]

    assert TabOrder.deserialize([
             %{"type" => "pm", "label" => "alice"},
             %{"type" => "channel", "label" => "#security"}
           ]) == order
  end
end
