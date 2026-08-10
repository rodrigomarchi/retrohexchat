defmodule RetroHexChatWeb.ChatLive.Helpers.PMTest do
  @moduledoc """
  Subscribing to a conversation, once.

  `Phoenix.PubSub.subscribe/2` is not idempotent — three calls deliver every
  broadcast three times — and the seven places that "ensure" a PM subscription
  were between them amplifying every incoming message by however many times the
  reader had walked into the conversation. Nothing showed it: the message stream
  is keyed by id and simply redrew the row it already had, while `capture_urls`,
  the flood tracker and the duplicate tracker each ran again.
  """
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.Helpers.PM

  @moduletag :unit

  defp socket_for(nickname) do
    %Socket{}
    |> Phoenix.Component.assign(session: Session.new(nickname))
    |> Phoenix.Component.assign(pm_subscriptions: MapSet.new())
  end

  defp deliveries(topic) do
    Phoenix.PubSub.broadcast(RetroHexChat.PubSub, topic, {:probe, topic})
    Process.sleep(50)
    {:messages, messages} = Process.info(self(), :messages)
    Enum.count(messages, &match?({:probe, ^topic}, &1))
  end

  describe "ensure_pm_subscription/2" do
    test "a conversation joined four times is still delivered once" do
      nickname = "pmt#{System.unique_integer([:positive])}"
      peer = "peer#{System.unique_integer([:positive])}"

      socket =
        Enum.reduce(1..4, socket_for(nickname), fn _n, acc ->
          PM.ensure_pm_subscription(acc, peer)
        end)

      assert MapSet.size(socket.assigns.pm_subscriptions) == 1
      assert deliveries("pm:#{PM.pm_topic(nickname, peer)}") == 1
    end

    test "a rename really re-subscribes, because the old topic was dropped" do
      nickname = "pmr#{System.unique_integer([:positive])}"
      peer = "old#{System.unique_integer([:positive])}"

      socket = PM.ensure_pm_subscription(socket_for(nickname), peer)
      assert PM.subscribed_to_pm?(socket, peer)

      socket = PM.drop_pm_subscription(socket, peer)
      refute PM.subscribed_to_pm?(socket, peer)

      _socket = PM.ensure_pm_subscription(socket, peer)
      assert deliveries("pm:#{PM.pm_topic(nickname, peer)}") == 1
    end

    test "the topic does not depend on who opened the conversation" do
      assert PM.pm_topic("ada", "grace") == PM.pm_topic("grace", "ada")
    end
  end
end
