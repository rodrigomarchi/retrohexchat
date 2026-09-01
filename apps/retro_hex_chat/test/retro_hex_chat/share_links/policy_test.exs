defmodule RetroHexChat.ShareLinks.PolicyTest do
  @moduledoc """
  Who may mint a share link, and who may close one.

  The half worth testing hardest is the second: `revoke/2` used to take whatever
  `revoked_by` it was handed and close the link, so the audit field was doing
  the job an authorization check was supposed to do.
  """
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  @moduletag :integration

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor
  alias RetroHexChat.ShareLinks
  alias RetroHexChat.ShareLinks.Policy
  alias RetroHexChat.ShareLinks.Schema.Link

  setup do
    %{nick: insert(:registered_nick)}
  end

  describe "can_create?/2" do
    test "a registered nickname may", %{nick: nick} do
      assert :ok = Policy.can_create?("play", nick.id)
    end

    test "an id behind no registration may not" do
      assert {:error, :unauthorized} = Policy.can_create?("play", -1)
    end

    test "no id at all may not" do
      assert {:error, :unauthorized} = Policy.can_create?("play", nil)
    end
  end

  describe "can_revoke?/2" do
    test "the creator may", %{nick: nick} do
      assert :ok =
               Policy.can_revoke?(
                 link_of(nick, "play", %{"game_id" => "hex_pong"}),
                 nick.nickname
               )
    end

    test "the creator's nickname is matched without regard to case", %{nick: nick} do
      link = link_of(nick, "play", %{"game_id" => "hex_pong"})

      assert :ok = Policy.can_revoke?(link, String.upcase(nick.nickname))
    end

    test "a stranger may not", %{nick: nick} do
      other = insert(:registered_nick)

      assert {:error, :unauthorized} =
               Policy.can_revoke?(
                 link_of(nick, "play", %{"game_id" => "hex_pong"}),
                 other.nickname
               )
    end

    test "nobody at all may not", %{nick: nick} do
      link = link_of(nick, "play", %{"game_id" => "hex_pong"})

      assert {:error, :unauthorized} = Policy.can_revoke?(link, nil)
      assert {:error, :unauthorized} = Policy.can_revoke?(link, "")
    end
  end

  # An operator who can close the conference but not the address people keep
  # arriving through has half a moderation tool.
  describe "the channel an address leads into" do
    # The first person into a channel is its founder, so every one of these
    # starts by parking somebody else there: a test where the subject is the
    # owner would pass on a rank nobody granted them.
    setup do
      channel = "#pol#{System.unique_integer([:positive])}"
      {:ok, pid} = Supervisor.start_child(channel)
      on_exit(fn -> if Process.alive?(pid), do: Supervisor.stop_child(Supervisor, pid) end)

      founder = insert(:registered_nick)
      {:ok, _state} = Server.join(channel, founder.nickname)

      %{channel: channel, founder: founder}
    end

    test "an operator may close a space link into their channel", ctx do
      %{nick: nick, channel: channel, founder: founder} = ctx
      op = insert(:registered_nick)

      {:ok, _state} = Server.join(channel, op.nickname)
      :ok = Server.set_mode(channel, founder.nickname, "+o", [op.nickname])

      link = link_of(nick, "space", %{"space_id" => channel, "mode" => "channel"})

      assert :ok = Policy.can_revoke?(link, op.nickname)
    end

    test "a plain member of the same channel may not", ctx do
      %{nick: nick, channel: channel} = ctx
      member = insert(:registered_nick)

      {:ok, _state} = Server.join(channel, member.nickname)

      link = link_of(nick, "space", %{"space_id" => channel, "mode" => "channel"})

      assert {:error, :unauthorized} = Policy.can_revoke?(link, member.nickname)
    end

    test "somebody who is not in the channel at all may not", ctx do
      %{nick: nick, channel: channel} = ctx
      stranger = insert(:registered_nick)

      link = link_of(nick, "space", %{"space_id" => channel, "mode" => "channel"})

      assert {:error, :unauthorized} = Policy.can_revoke?(link, stranger.nickname)
    end

    # A private space is keyed by its two people and a P2P session names nobody
    # else, so there is no channel and no operator of one.
    test "a link with no channel behind it reaches nobody but its creator", ctx do
      %{nick: nick, channel: channel, founder: founder} = ctx
      op = insert(:registered_nick)

      {:ok, _state} = Server.join(channel, op.nickname)
      :ok = Server.set_mode(channel, founder.nickname, "+o", [op.nickname])

      link = link_of(nick, "p2p", %{"session_token" => "whatever"})

      assert {:error, :unauthorized} = Policy.can_revoke?(link, op.nickname)
    end
  end

  defp link_of(nick, kind, target) do
    {:ok, %Link{} = link} =
      ShareLinks.create(%{
        kind: kind,
        target: target,
        creator_id: nick.id,
        creator_nick: nick.nickname
      })

    link
  end
end
