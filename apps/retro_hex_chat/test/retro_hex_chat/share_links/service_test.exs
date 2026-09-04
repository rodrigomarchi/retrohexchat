defmodule RetroHexChat.ShareLinks.ServiceTest do
  @moduledoc """
  Resolving a share link: what it says, and what it refuses to say.

  The four failure answers are deliberately different from each other for the
  creator and the same for a stranger — a link that distinguishes "no such link"
  from "a link you may not follow" is an oracle for whether a room exists.
  """
  use RetroHexChat.DataCase, async: true

  import RetroHexChat.Factory

  @moduletag :integration

  alias RetroHexChat.ShareLinks
  alias RetroHexChat.ShareLinks.Schema.Link
  alias RetroHexChat.VirtualSpace.Queries, as: SpaceQueries

  setup do
    nick = insert(:registered_nick)
    %{nick: nick}
  end

  describe "create/1" do
    test "mints a slug and remembers who made it", %{nick: nick} do
      assert {:ok, %Link{} = link} = create(nick, "play", %{"game_id" => "hex_pong"})

      assert link.creator_id == nick.id
      assert link.creator_nick == nick.nickname
      assert ShareLinks.Slug.valid?(link.slug)
      assert link.resolve_count == 0
      assert is_nil(link.revoked_at)
    end

    test "refuses a kind no surface answers to", %{nick: nick} do
      assert {:error, %Ecto.Changeset{}} = create(nick, "chat", %{})
    end

    # Sharing is a button, and a button gets pressed twice. Every press used to
    # mint another live slug, so "revoke the link" was never a whole sentence —
    # it closed one of an unknown number of siblings.
    test "the same room gets the same address, however many times it is asked for",
         %{nick: nick} do
      slugs =
        for _ <- 1..30, into: MapSet.new() do
          {:ok, link} = create(nick, "play", %{"game_id" => "hex_pong"})
          link.slug
        end

      assert MapSet.size(slugs) == 1
    end

    test "a different room is a different address", %{nick: nick} do
      {:ok, pong} = create(nick, "play", %{"game_id" => "hex_pong"})
      {:ok, trails} = create(nick, "play", %{"game_id" => "light_trails"})

      refute pong.slug == trails.slug
    end

    # Reuse is per person, because the row names who made it and revocation is
    # asked of them. Two people sharing one room are two accountable addresses.
    test "two people sharing the same room get their own address each", %{nick: nick} do
      other = insert(:registered_nick)

      {:ok, mine} = create(nick, "play", %{"game_id" => "hex_pong"})
      {:ok, theirs} = create(other, "play", %{"game_id" => "hex_pong"})

      refute mine.slug == theirs.slug
    end

    # A closed link is not reused: asking again after revoking is asking for a
    # new address, which is the only way back from having shared the wrong one.
    test "a revoked link is not handed back", %{nick: nick} do
      {:ok, first} = create(nick, "play", %{"game_id" => "hex_pong"})
      {:ok, _} = ShareLinks.revoke(first.slug, nick.nickname)

      {:ok, second} = create(nick, "play", %{"game_id" => "hex_pong"})

      refute second.slug == first.slug
    end

    test "an unregistered creator mints nothing" do
      assert {:error, :unauthorized} =
               ShareLinks.create(%{
                 kind: "play",
                 target: %{"game_id" => "hex_pong"},
                 creator_id: -1,
                 creator_nick: "ghost"
               })
    end
  end

  describe "resolve/1" do
    test "answers what the link points at", %{nick: nick} do
      {:ok, link} = create(nick, "play", %{"game_id" => "hex_pong"})

      assert {:ok, resolution} = ShareLinks.resolve(link.slug)
      assert resolution.kind == "play"
      assert resolution.target == %{"game_id" => "hex_pong"}
      assert resolution.creator_nick == nick.nickname
      assert resolution.live?
    end

    test "a game that left the catalogue is not live", %{nick: nick} do
      {:ok, link} = create(nick, "play", %{"game_id" => "no_such_game"})

      assert {:ok, resolution} = ShareLinks.resolve(link.slug)
      refute resolution.live?
    end

    # A link to the place never ends; a link to a gathering in it ends with the
    # gathering, and the two must not be confused at the door.
    test "a link to a gathering that ended is not live, and the place still is", %{nick: nick} do
      {:ok, gathering} =
        SpaceQueries.insert_session(%{
          token: "space#{System.unique_integer([:positive])}",
          space_id: "#gather#{System.unique_integer([:positive])}",
          kind: "channel",
          status: "closed",
          opened_by_nick: nick.nickname,
          opened_at: DateTime.add(DateTime.utc_now(), -1200, :second),
          closed_at: DateTime.add(DateTime.utc_now(), -60, :second),
          closed_reason: "emptied"
        })

      {:ok, ended} =
        create(nick, "space", %{
          "space_id" => gathering.space_id,
          "session_token" => gathering.token
        })

      {:ok, place} = create(nick, "space", %{"space_id" => gathering.space_id})

      assert {:ok, %{live?: false}} = ShareLinks.resolve(ended.slug)
      assert {:ok, %{live?: true}} = ShareLinks.resolve(place.slug)
    end

    test "counts a resolution, once", %{nick: nick} do
      {:ok, link} = create(nick, "play", %{"game_id" => "hex_pong"})

      assert {:ok, _} = ShareLinks.resolve(link.slug)
      assert {:ok, _} = ShareLinks.resolve(link.slug)

      assert Repo.get!(Link, link.id).resolve_count == 2
      assert Repo.get!(Link, link.id).last_resolved_at
    end

    test "does not count a resolution that failed" do
      assert {:error, :not_found} = ShareLinks.resolve("abcdefghjk")
    end

    # A malformed slug never reaches the database: it cannot be one.
    test "refuses a slug the generator could not have produced" do
      assert {:error, :not_found} = ShareLinks.resolve("NOPE")
      assert {:error, :not_found} = ShareLinks.resolve("")
      assert {:error, :not_found} = ShareLinks.resolve(nil)
    end

    test "a revoked link says so", %{nick: nick} do
      {:ok, link} = create(nick, "play", %{"game_id" => "hex_pong"})
      {:ok, _} = ShareLinks.revoke(link.slug, nick.nickname)

      assert {:error, :revoked} = ShareLinks.resolve(link.slug)
    end

    test "an expired link says so", %{nick: nick} do
      {:ok, link} =
        create(nick, "play", %{"game_id" => "hex_pong"},
          expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
        )

      assert {:error, :expired} = ShareLinks.resolve(link.slug)
    end

    test "a link with no expiry never expires", %{nick: nick} do
      {:ok, link} = create(nick, "play", %{"game_id" => "hex_pong"})

      assert {:ok, _} = ShareLinks.resolve(link.slug)
    end
  end

  describe "describe/1 and describe_many/1" do
    # Rendering a card in a channel is not somebody following the link. If the
    # two shared a function, a busy channel would inflate the one number that
    # answers whether sharing links actually brings anyone.
    test "reads without counting", %{nick: nick} do
      {:ok, link} = create(nick, "play", %{"game_id" => "hex_pong"})

      assert {:ok, described} = ShareLinks.describe(link.slug)
      assert described.kind == "play"
      assert described.live?

      assert Repo.get!(Link, link.id).resolve_count == 0
    end

    test "says the same thing resolve/1 says", %{nick: nick} do
      {:ok, link} = create(nick, "play", %{"game_id" => "hex_pong"})

      assert {:ok, described} = ShareLinks.describe(link.slug)
      assert {:ok, resolved} = ShareLinks.resolve(link.slug)

      assert described == resolved
    end

    test "refuses what resolve/1 refuses", %{nick: nick} do
      {:ok, link} = create(nick, "play", %{"game_id" => "hex_pong"})
      {:ok, _} = ShareLinks.revoke(link.slug, nick.nickname)

      assert {:error, :revoked} = ShareLinks.describe(link.slug)
      assert {:error, :not_found} = ShareLinks.describe("abcdefghjk")
      assert {:error, :not_found} = ShareLinks.describe("NOPE")
    end

    # One query for a screenful of messages, not one per message.
    test "describes many at once, skipping only what it never minted", %{nick: nick} do
      {:ok, a} = create(nick, "play", %{"game_id" => "hex_pong"})
      {:ok, b} = create(nick, "play", %{"game_id" => "light_trails"})

      described = ShareLinks.describe_many([a.slug, b.slug, "abcdefghjk", "NOPE"])

      assert Map.keys(described) |> Enum.sort() == Enum.sort([a.slug, b.slug])
      assert described[a.slug].target == %{"game_id" => "hex_pong"}
    end

    # `describe/1` refuses a closed link because somebody is trying to follow
    # it. A card is not somebody following it: it is the history of a message,
    # and filtering the closed ones out here did not grey the card out, it made
    # the card disappear and left a bare address under a message that had
    # explained itself the day before.
    test "a closed link is a card that says so, not an absence", %{nick: nick} do
      {:ok, gone} = create(nick, "play", %{"game_id" => "pixel_tanks"})
      {:ok, _} = ShareLinks.revoke(gone.slug, nick.nickname)

      described = ShareLinks.describe_many([gone.slug])

      assert %{state: :ended, reason: :revoked} = described[gone.slug]
      assert {:error, :revoked} = ShareLinks.describe(gone.slug)
    end

    test "counts nothing at all", %{nick: nick} do
      {:ok, link} = create(nick, "play", %{"game_id" => "hex_pong"})

      ShareLinks.describe_many([link.slug])

      assert Repo.get!(Link, link.id).resolve_count == 0
    end

    test "an empty list asks the database nothing" do
      assert ShareLinks.describe_many([]) == %{}
    end
  end

  describe "revoke/2" do
    test "closes the link without touching what it points at", %{nick: nick} do
      {:ok, link} = create(nick, "play", %{"game_id" => "hex_pong"})

      assert {:ok, revoked} = ShareLinks.revoke(link.slug, nick.nickname)
      assert revoked.revoked_by == nick.nickname
      assert revoked.revoked_at
    end

    test "revoking twice is not an error the caller has to handle", %{nick: nick} do
      {:ok, link} = create(nick, "play", %{"game_id" => "hex_pong"})

      assert {:ok, _} = ShareLinks.revoke(link.slug, nick.nickname)
      assert {:ok, _} = ShareLinks.revoke(link.slug, nick.nickname)
    end

    test "an unknown slug is not found", %{nick: nick} do
      assert {:error, :not_found} = ShareLinks.revoke("abcdefghjk", nick.nickname)
    end

    # The name on the row is not a permission. A `revoke/2` that took whatever
    # `revoked_by` it was handed and closed the link would leave the audit field
    # doing the work an authorization check is supposed to.
    test "a stranger cannot close somebody else's link", %{nick: nick} do
      other = insert(:registered_nick)
      {:ok, link} = create(nick, "play", %{"game_id" => "hex_pong"})

      assert {:error, :unauthorized} = ShareLinks.revoke(link.slug, other.nickname)
      assert {:ok, %{live?: true}} = ShareLinks.describe(link.slug)
    end
  end

  defp create(nick, kind, target, opts \\ []) do
    ShareLinks.create(%{
      kind: kind,
      target: target,
      creator_id: nick.id,
      creator_nick: nick.nickname,
      expires_at: Keyword.get(opts, :expires_at)
    })
  end
end
