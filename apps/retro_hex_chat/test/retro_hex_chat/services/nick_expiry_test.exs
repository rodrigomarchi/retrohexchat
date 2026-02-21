defmodule RetroHexChat.Services.NickExpiryTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Repo
  alias RetroHexChat.Services.{NickExpiry, NickServ, Queries}

  setup do
    nickserv_name = :"nickserv_expiry_#{System.unique_integer([:positive])}"
    {:ok, _} = NickServ.start_link(name: nickserv_name)

    expiry_name = :"expiry_#{System.unique_integer([:positive])}"

    {:ok, _} =
      NickExpiry.start_link(
        name: expiry_name,
        nickserv: nickserv_name,
        purge_interval_ms: :timer.hours(24),
        expiration_days: 7
      )

    %{expiry: expiry_name, nickserv: nickserv_name}
  end

  defp register_nick(nickname, password, last_seen_days_ago) do
    {:ok, nick} = Queries.insert_registered_nick(nickname, password)

    last_seen = DateTime.add(DateTime.utc_now(), -last_seen_days_ago, :day)

    nick
    |> Ecto.Changeset.change(last_seen_at: last_seen)
    |> Repo.update!()
  end

  describe "purge" do
    test "deletes nicks with last_seen_at older than 7 days", ctx do
      register_nick("OldNick1", "pass12345", 8)
      register_nick("OldNick2", "pass12345", 10)

      {count, nicknames} = NickExpiry.run_now(ctx.expiry)

      assert count == 2
      assert "OldNick1" in nicknames
      assert "OldNick2" in nicknames
      assert Queries.find_by_nickname("OldNick1") == nil
      assert Queries.find_by_nickname("OldNick2") == nil
    end

    test "does not delete nicks with recent last_seen_at", ctx do
      register_nick("RecentNick", "pass12345", 3)

      {count, nicknames} = NickExpiry.run_now(ctx.expiry)

      assert count == 0
      assert nicknames == []
      assert Queries.find_by_nickname("RecentNick") != nil
    end

    test "does not delete nicks that are currently identified (protected)", ctx do
      register_nick("ConnNick", "pass12345", 8)
      NickServ.register("ConnNick2", "pass12345", ctx.nickserv)

      # ConnNick2 is auto-identified after registration, make it old
      nick2 = Queries.find_by_nickname("ConnNick2")

      nick2
      |> Ecto.Changeset.change(last_seen_at: DateTime.add(DateTime.utc_now(), -10, :day))
      |> Repo.update!()

      {count, nicknames} = NickExpiry.run_now(ctx.expiry)

      # ConnNick should be purged (old, not identified)
      # ConnNick2 should be protected (old, but identified)
      assert count == 1
      assert "ConnNick" in nicknames
      refute "ConnNick2" in nicknames
      assert Queries.find_by_nickname("ConnNick2") != nil
    end

    test "removes purged nicks from NickServ identified set", ctx do
      NickServ.register("PurgeId", "pass12345", ctx.nickserv)
      assert NickServ.identified?("PurgeId", ctx.nickserv)

      # Make it old but remove from identified first so it gets purged
      nick = Queries.find_by_nickname("PurgeId")

      nick
      |> Ecto.Changeset.change(last_seen_at: DateTime.add(DateTime.utc_now(), -10, :day))
      |> Repo.update!()

      NickServ.remove_identified("PurgeId", ctx.nickserv)

      {count, _} = NickExpiry.run_now(ctx.expiry)
      assert count == 1
      refute NickServ.identified?("PurgeId", ctx.nickserv)
    end
  end

  describe "list_identified/1" do
    test "returns currently identified nicks", ctx do
      NickServ.register("ListId1", "pass12345", ctx.nickserv)
      NickServ.register("ListId2", "pass12345", ctx.nickserv)

      identified = NickServ.list_identified(ctx.nickserv)
      assert "ListId1" in identified
      assert "ListId2" in identified
    end
  end

  describe "remove_identified/2" do
    test "removes nick from identified set", ctx do
      NickServ.register("RemId", "pass12345", ctx.nickserv)
      assert NickServ.identified?("RemId", ctx.nickserv)

      NickServ.remove_identified("RemId", ctx.nickserv)
      refute NickServ.identified?("RemId", ctx.nickserv)
    end
  end
end
