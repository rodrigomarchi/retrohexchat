defmodule RetroHexChatWeb.ChatLive.Helpers.SessionCardTest do
  use RetroHexChatWeb.ConnCase, async: true

  alias RetroHexChat.Arcade.Schema.SoloSession
  alias RetroHexChat.Lobby.Schema.Session, as: LobbySession
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.VirtualSpace.Queries, as: SpaceQueries
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

  defp arcade_session(attrs) do
    {:ok, s} =
      %SoloSession{}
      |> SoloSession.changeset(attrs)
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

  describe "enrich/1 for :arcade_link" do
    test "attaches a resolved arcade card with the game name" do
      creator = nick("rodrigo")

      arcade_session(%{
        token: "arc_tok",
        creator_id: creator.id,
        status: "playing",
        game_id: "doom_shareware"
      })

      item = %{type: :arcade_link, content: "https://example.test/activity/solo/arc_tok"}

      enriched = SessionCard.enrich(item)
      card = enriched.session_card

      assert card.kind == :arcade
      assert card.created_by == "rodrigo"
      assert card.game_name == "DOOM: Knee-Deep in the Dead"
      assert card.href == "https://example.test/activity/solo/arc_tok"
    end
  end

  describe "enrich/1 for :space_invite" do
    test "attaches a resolved virtual space card" do
      creator = nick("rodrigo")

      {:ok, _} =
        SpaceQueries.insert_session(%{
          token: "spc_tok",
          channel_name: "#general",
          creator_id: creator.id,
          creator_nick: creator.nickname,
          title: "Guild Tavern",
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      item = %{
        type: :space_invite,
        content: "Virtual space ready. Enter the space: /space/spc_tok"
      }

      enriched = SessionCard.enrich(item)
      card = enriched.session_card

      assert card.kind == :space
      assert card.title == "Guild Tavern"
      assert card.creator_nick == "rodrigo"
      assert card.channel_name == "#general"
      assert card.map_id == "tavern_cafe_v1"
      assert card.status == "pending"
      assert card.href == "/space/spc_tok"
    end

    test "leaves the item untouched when the space is unknown (fallback)" do
      item = %{type: :space_invite, content: "Enter the space: /space/ghost_token"}
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
