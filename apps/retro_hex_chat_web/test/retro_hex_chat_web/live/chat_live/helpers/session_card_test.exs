defmodule RetroHexChatWeb.ChatLive.Helpers.SessionCardTest do
  use RetroHexChatWeb.ConnCase, async: true

  alias RetroHexChat.Lobby.Schema.Session, as: LobbySession
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChatWeb.ChatLive.Helpers.SessionCard

  @moduletag :integration

  defp nick(name) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: name, password: "password123"})
      |> Repo.insert()

    nick
  end

  defp lobby_session(attrs) do
    {:ok, s} =
      %LobbySession{}
      |> LobbySession.changeset(attrs)
      |> Repo.insert()

    s
  end

  describe "enrich/1 for :p2p_invite" do
    test "attaches a resolved lobby card with creator and peer nicks" do
      creator = nick("rodrigo")
      peer = nick("alice")

      lobby_session(%{
        token: "lob_tok",
        creator_id: creator.id,
        peer_id: peer.id,
        status: "connected"
      })

      item = %{
        type: :p2p_invite,
        content: "P2P lobby ready. Join the lobby: /lobby/lob_tok"
      }

      enriched = SessionCard.enrich(item)
      card = enriched.session_card

      assert card.kind == :lobby
      assert card.created_by == "rodrigo"
      assert card.peer == "alice"
      assert card.status == "connected"
      assert card.href == "/lobby/lob_tok"
    end

    test "leaves the item untouched when the session is unknown (fallback)" do
      item = %{type: :p2p_invite, content: "Join the lobby: /lobby/ghost_token"}
      assert SessionCard.enrich(item) == item
    end
  end

  describe "enrich/1 for other types" do
    test "passes non-session messages through unchanged" do
      item = %{type: :normal, content: "hello /lobby/xyz in a sentence"}
      assert SessionCard.enrich(item) == item
    end
  end
end
