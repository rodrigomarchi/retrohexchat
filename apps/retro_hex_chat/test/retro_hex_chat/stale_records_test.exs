defmodule RetroHexChat.StaleRecordsTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Arcade.Queries, as: ArcadeQueries
  alias RetroHexChat.Arcade.Schema.SoloSession
  alias RetroHexChat.Services.Queries, as: ServiceQueries
  alias RetroHexChat.StaleRecords

  @spec_ StaleRecords.new(SoloSession, ~w(finished closed expired))

  setup do
    n = System.unique_integer([:positive]) |> rem(10_000)
    {:ok, nick} = ServiceQueries.insert_registered_nick("stale#{n}", "secret123")

    now = DateTime.utc_now()

    {:ok, creator: nick, now: now, cutoff: DateTime.add(now, -300, :second)}
  end

  defp session!(creator, status, seconds_ago, now) do
    {:ok, session} =
      ArcadeQueries.insert_session(%{
        token: "stale-#{System.unique_integer([:positive])}",
        creator_id: creator.id,
        status: status
      })

    from(record in SoloSession, where: record.id == ^session.id)
    |> Repo.update_all(set: [updated_at: DateTime.add(now, -seconds_ago, :second)])

    Repo.get!(SoloSession, session.id)
  end

  describe "list/3" do
    test "a row nobody has touched since the cutoff is stale", ctx do
      session = session!(ctx.creator, "playing", 600, ctx.now)

      assert [%SoloSession{id: id}] = StaleRecords.list(@spec_, ctx.cutoff)
      assert id == session.id
    end

    test "a row touched after the cutoff is not stale, however open", ctx do
      session!(ctx.creator, "playing", 60, ctx.now)

      assert StaleRecords.list(@spec_, ctx.cutoff) == []
    end

    test "a row that reached a terminal status is not stale, however old", ctx do
      for status <- ~w(finished closed expired) do
        session!(ctx.creator, status, 600, ctx.now)
      end

      assert StaleRecords.list(@spec_, ctx.cutoff) == []
    end

    test "oldest first, so a limited pass takes what has been open longest", ctx do
      recent = session!(ctx.creator, "playing", 400, ctx.now)
      oldest = session!(ctx.creator, "playing", 9_000, ctx.now)
      middle = session!(ctx.creator, "playing", 1_200, ctx.now)

      ids = @spec_ |> StaleRecords.list(ctx.cutoff) |> Enum.map(& &1.id)

      assert ids == [oldest.id, middle.id, recent.id]
    end

    test "a limit takes the oldest rows rather than an arbitrary slice", ctx do
      _recent = session!(ctx.creator, "playing", 400, ctx.now)
      oldest = session!(ctx.creator, "playing", 9_000, ctx.now)
      middle = session!(ctx.creator, "playing", 1_200, ctx.now)

      ids = @spec_ |> StaleRecords.list(ctx.cutoff, limit: 2) |> Enum.map(& &1.id)

      assert ids == [oldest.id, middle.id]
    end

    test "no limit means every stale row", ctx do
      for _ <- 1..3, do: session!(ctx.creator, "playing", 600, ctx.now)

      assert length(StaleRecords.list(@spec_, ctx.cutoff)) == 3
      assert length(StaleRecords.list(@spec_, ctx.cutoff, limit: nil)) == 3
    end
  end

  describe "count/2" do
    test "counts what a sweep would have to close, past any limit", ctx do
      for _ <- 1..3, do: session!(ctx.creator, "playing", 600, ctx.now)
      session!(ctx.creator, "playing", 60, ctx.now)
      session!(ctx.creator, "closed", 600, ctx.now)

      assert StaleRecords.count(@spec_, ctx.cutoff) == 3
    end
  end

  describe "expire/3" do
    test "closes a stale row and records why", ctx do
      session = session!(ctx.creator, "playing", 600, ctx.now)

      assert {:ok, :expired} = StaleRecords.expire(@spec_, session.id, ctx.cutoff)

      expired = Repo.get!(SoloSession, session.id)
      assert expired.status == "expired"
      assert expired.closed_reason == "stale_cleanup"
      assert expired.closed_at != nil
    end

    test "a row touched between listing and writing is skipped, not closed", ctx do
      session = session!(ctx.creator, "playing", 600, ctx.now)

      [candidate] = StaleRecords.list(@spec_, ctx.cutoff)

      from(record in SoloSession, where: record.id == ^candidate.id)
      |> Repo.update_all(set: [updated_at: DateTime.add(ctx.now, -60, :second)])

      assert {:ok, :skipped} = StaleRecords.expire(@spec_, candidate.id, ctx.cutoff)
      assert Repo.get!(SoloSession, session.id).status == "playing"
    end

    test "a row that closed itself in the meantime is skipped", ctx do
      session = session!(ctx.creator, "playing", 600, ctx.now)

      from(record in SoloSession, where: record.id == ^session.id)
      |> Repo.update_all(set: [status: "finished"])

      assert {:ok, :skipped} = StaleRecords.expire(@spec_, session.id, ctx.cutoff)
      assert Repo.get!(SoloSession, session.id).status == "finished"
    end

    test "a row that no longer exists is skipped rather than raising", ctx do
      assert {:ok, :skipped} = StaleRecords.expire(@spec_, 0, ctx.cutoff)
    end
  end
end
