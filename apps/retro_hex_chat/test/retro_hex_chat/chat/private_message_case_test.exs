defmodule RetroHexChat.Chat.PrivateMessageCaseTest do
  @moduledoc "A private message reaches its person whatever case their nickname is typed in."

  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.{Queries, Service}
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Topics

  defp unique(prefix), do: "#{prefix}#{rem(System.unique_integer([:positive]), 100_000)}"

  test "a message to alice arrives live for AlIcE and is filed under her spelling" do
    shown = unique("AlIcE")
    {:ok, _} = Tracker.track_user(Topics.presence(), shown)
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(shown))

    assert {:ok, pm} = Service.send_private_message("Bob", String.downcase(shown), "hi there")

    assert pm.recipient_nickname == shown
    assert_receive %{event: "new_pm", payload: %{content: "hi there", direction: :incoming}}
  end

  test "spellings of one partner are one conversation, shown as last spelled" do
    me = unique("Me")
    {:ok, _} = Service.send_private_message(me, "carol", "first")
    {:ok, _} = Service.send_private_message("CAROL", me, "second")

    page = Queries.list_pm_partners(String.upcase(me))

    assert [%{nickname: "CAROL"}] = page.items
  end
end
