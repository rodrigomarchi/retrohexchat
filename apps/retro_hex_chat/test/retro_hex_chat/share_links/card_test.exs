defmodule RetroHexChat.ShareLinks.CardTest do
  @moduledoc """
  The room a shared link names, as of now.

  Two things are asserted here and nowhere else: that a link closed by hand
  outranks whatever the room is still doing, and that a match link dies by
  **success** — the seat it offered was taken, which is a different sentence
  from "expired" because it names something that worked.
  """
  use RetroHexChat.DataCase, async: true

  import RetroHexChat.Factory

  @moduletag :integration

  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Queries
  alias RetroHexChat.ShareLinks.Card
  alias RetroHexChat.ShareLinks.Schema.Link

  describe "of/1 for a game" do
    test "a solo game is live as long as the catalogue has it" do
      assert %{state: :live, game_id: "hex_pong"} =
               Card.of(link("play", %{"game_id" => "hex_pong"}))
    end

    test "a game the catalogue does not have is over" do
      assert %{state: :ended, reason: :over} = Card.of(link("play", %{"game_id" => "nope"}))
    end
  end

  describe "of/1 for a match" do
    setup do
      creator = insert(:registered_nick)
      {:ok, session} = Lobby.create_open_session(creator.id)
      %{creator: creator, session: session}
    end

    test "an unclaimed seat is live and says there is one", %{session: session} do
      card = Card.of(link("play", %{"game_id" => "hex_pong", "session_token" => session.token}))

      assert card.state == :live
      assert card.count == 1
    end

    # Dying by success is the one ending that is not a failure, and the card
    # has to be able to say which it was.
    test "a seat somebody took is full, not expired", %{session: session} do
      claimer = insert(:registered_nick)
      # The conditional write is the claim; `Lobby.claim_open_session/2` also
      # starts the session's process, which cannot see this test's sandbox
      # connection. What the card reads is the row.
      {:ok, _claimed} = Queries.claim_open_session(session.token, claimer.id)

      card = Card.of(link("play", %{"game_id" => "hex_pong", "session_token" => session.token}))

      assert card.state == :ended
      assert card.reason == :full
    end
  end

  describe "of/1 and a link closed by hand" do
    test "revoking outranks a room that is still running" do
      card = Card.of(%{link("play", %{"game_id" => "hex_pong"}) | revoked_at: DateTime.utc_now()})

      assert card.state == :ended
      assert card.reason == :revoked
    end

    test "an expiry in the past does the same" do
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      card = Card.of(%{link("play", %{"game_id" => "hex_pong"}) | expires_at: past})

      assert card.state == :ended
      assert card.reason == :expired
    end

    test "an expiry in the future does not" do
      future = DateTime.add(DateTime.utc_now(), 3600, :second)
      card = Card.of(%{link("play", %{"game_id" => "hex_pong"}) | expires_at: future})

      assert card.state == :live
    end
  end

  describe "of/1 and a channel that may not be named" do
    # A channel nobody can reach is not nameable — silence is not permission —
    # so a card for a room in a channel with no process names nothing. That is
    # the safe direction, and it is the one a test can assert without standing
    # up a channel server.
    test "a call whose channel is unreachable carries no name" do
      card = Card.of(link("call", %{"room_token" => "nope", "channel_name" => "#secret"}))

      assert card.channel_name == nil
    end

    test "a space in an unreachable channel carries no name either" do
      card = Card.of(link("space", %{"space_id" => "#secret"}))

      assert card.channel_name == nil
    end
  end

  defp link(kind, target) do
    %Link{
      slug: "abcdefghjk",
      kind: kind,
      target: target,
      creator_nick: "ana",
      revoked_at: nil,
      expires_at: nil
    }
  end
end
