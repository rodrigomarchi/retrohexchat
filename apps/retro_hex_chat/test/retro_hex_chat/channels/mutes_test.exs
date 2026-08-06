defmodule RetroHexChat.Channels.MutesTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.{ChannelMute, Mutes}
  alias RetroHexChat.Jobs.ChannelMuteExpiryWorker

  test "creates a permanent active mute without scheduling expiry" do
    assert {:ok, mute} = Mutes.mute("#mutes", "Oper", "Target", :permanent)

    assert mute.channel_name == "#mutes"
    assert mute.target_nickname == "Target"
    assert mute.normalized_target == "target"
    assert mute.operator_nickname == "Oper"
    assert is_nil(mute.expires_at)
    assert Mutes.active_nicknames("#mutes") == ["Target"]
    assert Mutes.active_count() == 1
    assert all_enqueued(worker: ChannelMuteExpiryWorker, queue: :maintenance) == []
  end

  test "creates a temporary mute and schedules a unique expiry job" do
    now = DateTime.utc_now()

    assert {:ok, mute} = Mutes.mute("#mutes-temp", "Oper", "Target", 60, now: now)

    assert %DateTime{} = mute.expires_at
    assert DateTime.diff(mute.expires_at, now, :second) == 60

    assert_enqueued(
      worker: ChannelMuteExpiryWorker,
      queue: :maintenance,
      args: %{mute_id: mute.id}
    )
  end

  test "re-muting the same target reuses active row and replaces expiry" do
    now = DateTime.utc_now()

    assert {:ok, first} = Mutes.mute("#mutes-replace", "Oper", "Target", 30, now: now)
    assert {:ok, second} = Mutes.mute("#mutes-replace", "Oper2", "Target", 120, now: now)

    assert second.id == first.id
    assert second.operator_nickname == "Oper2"
    assert DateTime.diff(second.expires_at, now, :second) == 120
    assert Repo.aggregate(ChannelMute, :count, :id) == 1
  end

  test "manual revoke marks mute revoked and cancels expiry job" do
    assert {:ok, mute} = Mutes.mute("#mutes-revoke", "Oper", "Target", 60)

    assert_enqueued(
      worker: ChannelMuteExpiryWorker,
      queue: :maintenance,
      args: %{mute_id: mute.id}
    )

    assert {:ok, %{revoked: 1}} = Mutes.revoke_active("#mutes-revoke", "Target", "Oper")

    reloaded = Repo.get!(ChannelMute, mute.id)

    assert reloaded.revoked_at
    assert reloaded.revoked_by_nickname == "Oper"
    assert reloaded.revoke_reason == "manual"
    assert Mutes.active_nicknames("#mutes-revoke") == []
    assert all_enqueued(worker: ChannelMuteExpiryWorker, queue: :maintenance) == []
  end

  test "expire_due materializes a due mute and ignores already revoked mutes" do
    now = DateTime.utc_now()
    past = DateTime.add(now, -60, :second)
    future = DateTime.add(now, 60, :second)

    assert {:ok, due} =
             Mutes.mute("#mutes-due", "Oper", "Due", 60, now: DateTime.add(now, -120, :second))

    assert {:ok, {:expired, expired}} = Mutes.expire_due(due.id, now: now)

    assert expired.revoked_by_nickname == "system"
    assert expired.revoke_reason == "expired"
    assert Mutes.expired_count(now: now) == 0

    assert {:ok, manual} = Mutes.mute("#mutes-due", "Oper", "Manual", :permanent, now: past)
    assert {:ok, %{revoked: 1}} = Mutes.revoke_active("#mutes-due", "Manual", "Oper", now: now)
    assert {:ok, {:noop, _mute}} = Mutes.expire_due(manual.id, now: now)

    assert {:ok, not_due} = Mutes.mute("#mutes-due", "Oper", "Future", 120, now: now)
    assert {:ok, {:not_due, _mute, seconds}} = Mutes.expire_due(not_due.id, now: future)
    assert seconds > 0
  end
end
