defmodule RetroHexChat.ShareLinks.ChannelLinkTest do
  @moduledoc """
  A link that names a channel.

  The kinds that came before all name a room built for one gathering: a call, a
  match, a space session. A channel outlives every gathering in it, so its link
  is alive for as long as the channel is a place somebody could be told about —
  and dead the moment it is one they could not.
  """
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  @moduletag :integration

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor
  alias RetroHexChat.Services.Queries, as: ServiceQueries
  alias RetroHexChat.ShareLinks.{Card, Liveness, Policy}
  alias RetroHexChat.ShareLinks.Schema.Link

  defp unique(prefix), do: "##{prefix}#{System.unique_integer([:positive])}"

  defp registered(name, opts \\ []) do
    {:ok, _} = ServiceQueries.insert_registered_channel(name, "Founder")
    ServiceQueries.update_registered_channel_settings(name, modes: Keyword.get(opts, :modes, ""))

    on_exit(fn ->
      case ServiceQueries.find_registered_channel(name) do
        nil -> :ok
        channel -> ServiceQueries.delete_registered_channel(channel)
      end
    end)

    name
  end

  defp running(name) do
    {:ok, pid} = Supervisor.start_child(name)
    on_exit(fn -> if Process.alive?(pid), do: Supervisor.stop_child(pid) end)
    name
  end

  defp target(name), do: %{"channel" => name}

  describe "Liveness.live?/2" do
    test "a registered channel nobody is in is live — a place does not end" do
      name = registered(unique("livecold"))

      assert Liveness.live?("channel", target(name))
    end

    test "a running channel is live even when it was never registered" do
      name = running(unique("liverun"))

      assert Liveness.live?("channel", target(name))
    end

    test "a channel that is neither running nor registered is not" do
      refute Liveness.live?("channel", target(unique("livegone")))
    end

    test "a secret channel is not, however alive it is" do
      name = registered(unique("livesecret"), modes: "+s")

      refute Liveness.live?("channel", target(name))
    end

    test "a target that names nothing is not" do
      refute Liveness.live?("channel", %{})
    end
  end

  describe "Card.of/1" do
    test "counts who is in the channel right now" do
      name = running(unique("cardcount"))
      {:ok, _} = Server.join(name, "Alice")
      {:ok, _} = Server.join(name, "Bob")

      card = Card.of(link(name))

      assert card.state == :live
      assert card.count == 2
      assert card.channel_name == name
    end

    test "a room nobody is in is still live, with nobody in it" do
      name = registered(unique("cardcold"))

      card = Card.of(link(name))

      assert card.state == :live
      assert card.count == 0
    end

    # The card travels to people who are not in the channel and may not be in
    # the product; naming a channel they could not have listed is the leak.
    test "an invite-only channel is not named on its own card" do
      name = registered(unique("cardinvite"), modes: "+i")

      assert Card.of(link(name)).channel_name == nil
    end

    test "a channel that is gone reads as over, not as a blank" do
      card = Card.of(link(unique("cardgone")))

      assert card.state == :ended
      assert card.reason == :over
    end
  end

  describe "Policy.can_create?/2 for a channel" do
    setup do
      %{nick: insert(:registered_nick)}
    end

    test "a member may", %{nick: nick} do
      name = running(unique("polmember"))
      {:ok, _} = Server.join(name, nick.nickname)

      assert :ok = Policy.can_create?("channel", nick.id, target(name))
    end

    test "somebody who is not in the channel may not", %{nick: nick} do
      name = running(unique("polstranger"))

      assert {:error, :unauthorized} = Policy.can_create?("channel", nick.id, target(name))
    end

    # An invite-only channel decides who comes in; handing its address out is
    # the same decision, so it belongs to the same people.
    test "an ordinary member of an invite-only channel may not", %{nick: nick} do
      name = running(unique("polinvite"))
      {:ok, _} = Server.join(name, "Owner")
      {:ok, _} = Server.join(name, nick.nickname)
      :ok = Server.set_mode(name, "Owner", "+i")

      assert {:error, :unauthorized} = Policy.can_create?("channel", nick.id, target(name))
    end

    test "an operator of an invite-only channel may", %{nick: nick} do
      name = running(unique("polinviteop"))
      {:ok, _} = Server.join(name, nick.nickname)
      :ok = Server.set_mode(name, nick.nickname, "+i")

      assert :ok = Policy.can_create?("channel", nick.id, target(name))
    end
  end

  defp link(name) do
    %Link{
      slug: "abcdefghjk",
      kind: "channel",
      target: target(name),
      creator_id: 1,
      creator_nick: "ana"
    }
  end
end
