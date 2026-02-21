defmodule RetroHexChat.Services.ChanExpiryTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Repo
  alias RetroHexChat.Services.{ChanExpiry, NickExpiry, NickServ, Queries}

  setup do
    nickserv_name = :"nickserv_chanexp_#{System.unique_integer([:positive])}"
    {:ok, _} = NickServ.start_link(name: nickserv_name)

    nick_expiry_name = :"nick_expiry_chanexp_#{System.unique_integer([:positive])}"

    {:ok, _} =
      NickExpiry.start_link(
        name: nick_expiry_name,
        nickserv: nickserv_name,
        purge_interval_ms: :timer.hours(24),
        expiration_days: 7
      )

    chan_expiry_name = :"chan_expiry_#{System.unique_integer([:positive])}"

    {:ok, _} =
      ChanExpiry.start_link(
        name: chan_expiry_name,
        purge_interval_ms: :timer.hours(24),
        expiration_days: 7
      )

    %{
      chan_expiry: chan_expiry_name,
      nick_expiry: nick_expiry_name,
      nickserv: nickserv_name
    }
  end

  defp register_channel(name, founder) do
    {:ok, channel} = Queries.insert_registered_channel(name, founder)
    Queries.add_access(name, founder, "founder", founder)
    channel
  end

  defp backdate_channel_activity(name, days_ago) do
    activity_at = DateTime.add(DateTime.utc_now(), -days_ago, :day)

    Queries.find_registered_channel(name)
    |> Ecto.Changeset.change(last_activity_at: activity_at)
    |> Repo.update!()
  end

  defp register_nick(nickname, password, last_seen_days_ago) do
    {:ok, nick} = Queries.insert_registered_nick(nickname, password)

    last_seen = DateTime.add(DateTime.utc_now(), -last_seen_days_ago, :day)

    nick
    |> Ecto.Changeset.change(last_seen_at: last_seen)
    |> Repo.update!()
  end

  describe "channel purge" do
    test "purges channels with last_activity_at older than 7 days", ctx do
      register_channel("#old-chan1", "Founder1")
      backdate_channel_activity("#old-chan1", 8)

      register_channel("#old-chan2", "Founder2")
      backdate_channel_activity("#old-chan2", 10)

      {count, names} = ChanExpiry.run_now(ctx.chan_expiry)

      assert count == 2
      assert "#old-chan1" in names
      assert "#old-chan2" in names
      assert Queries.find_registered_channel("#old-chan1") == nil
      assert Queries.find_registered_channel("#old-chan2") == nil
    end

    test "does not purge recent channels", ctx do
      register_channel("#recent-chan", "Founder1")
      backdate_channel_activity("#recent-chan", 3)

      {count, names} = ChanExpiry.run_now(ctx.chan_expiry)

      assert count == 0
      assert names == []
      assert Queries.find_registered_channel("#recent-chan") != nil
    end

    test "cleans up access, bans, exceptions, and welcome messages on purge", ctx do
      register_channel("#cleanup-chan", "CleanFounder")
      Queries.add_access("#cleanup-chan", "SomeUser", "sop", "CleanFounder")
      Queries.add_ban("#cleanup-chan", "BadUser", "CleanFounder", "reason")
      Queries.add_ban_exception("#cleanup-chan", "GoodUser", "CleanFounder")
      Queries.add_invite_exception("#cleanup-chan", "InvUser", "CleanFounder")
      Queries.upsert_welcome_message("#cleanup-chan", "Welcome!", "CleanFounder")

      backdate_channel_activity("#cleanup-chan", 8)

      {count, _} = ChanExpiry.run_now(ctx.chan_expiry)
      assert count == 1

      assert Queries.list_access("#cleanup-chan") == []
      assert Queries.list_bans("#cleanup-chan") == []
      assert Queries.list_ban_exceptions("#cleanup-chan") == []
      assert Queries.list_invite_exceptions("#cleanup-chan") == []
      assert Queries.get_welcome_message("#cleanup-chan") == nil
    end
  end

  describe "touch_channel_activity" do
    test "updates last_activity_at timestamp" do
      register_channel("#touch-chan", "TouchFounder")
      backdate_channel_activity("#touch-chan", 5)

      Queries.touch_channel_activity("#touch-chan")

      channel = Queries.find_registered_channel("#touch-chan")
      diff = DateTime.diff(DateTime.utc_now(), channel.last_activity_at, :second)
      assert diff < 5
    end
  end

  describe "nick expiry founder succession" do
    test "promotes SOP as new founder when founder nick expires", ctx do
      register_nick("FounderNick", "pass12345", 8)
      register_channel("#succession-chan", "FounderNick")
      Queries.add_access("#succession-chan", "SopUser", "sop", "FounderNick")

      NickExpiry.run_now(ctx.nick_expiry)

      channel = Queries.find_registered_channel("#succession-chan")
      assert channel != nil
      assert channel.founder_nickname == "SopUser"

      access = Queries.find_access("#succession-chan", "SopUser")
      assert access != nil
      assert access.level == "founder"

      # Old founder's access should be removed
      assert Queries.find_access("#succession-chan", "FounderNick") == nil
    end

    test "promotes by rank order (SOP before AOP)", ctx do
      register_nick("RankFounder", "pass12345", 8)
      register_channel("#rank-chan", "RankFounder")
      Queries.add_access("#rank-chan", "AopUser", "aop", "RankFounder")
      Queries.add_access("#rank-chan", "SopUser", "sop", "RankFounder")

      NickExpiry.run_now(ctx.nick_expiry)

      channel = Queries.find_registered_channel("#rank-chan")
      assert channel != nil
      assert channel.founder_nickname == "SopUser"
    end

    test "deregisters channel when no successors exist", ctx do
      register_nick("LoneFounder", "pass12345", 8)
      register_channel("#lone-chan", "LoneFounder")

      NickExpiry.run_now(ctx.nick_expiry)

      assert Queries.find_registered_channel("#lone-chan") == nil
      assert Queries.list_access("#lone-chan") == []
    end

    test "deregistered channel can be re-registered by anyone", ctx do
      register_nick("OldFounder", "pass12345", 8)
      register_channel("#reuse-chan", "OldFounder")

      NickExpiry.run_now(ctx.nick_expiry)
      assert Queries.find_registered_channel("#reuse-chan") == nil

      {:ok, channel} = Queries.insert_registered_channel("#reuse-chan", "NewFounder")
      assert channel.founder_nickname == "NewFounder"
    end
  end
end
