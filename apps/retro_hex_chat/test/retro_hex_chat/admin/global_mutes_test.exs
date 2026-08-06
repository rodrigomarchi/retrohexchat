defmodule RetroHexChat.Admin.GlobalMutesTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Admin.{GlobalMute, GlobalMutes}
  alias RetroHexChat.Jobs.GlobalMuteExpiryWorker

  setup do
    GlobalMutes.reload_cache()
    :ok
  end

  test "creates a permanent durable mute and updates cache" do
    assert :ok = GlobalMutes.mute("MutedUser", "Admin", "spam", :permanent)

    assert GlobalMutes.muted?("MutedUser")
    assert GlobalMutes.muted?("muteduser")
    assert GlobalMutes.active_count() == 1
    assert all_enqueued(worker: GlobalMuteExpiryWorker, queue: :maintenance) == []

    mute = Repo.one!(GlobalMute)
    assert mute.nickname == "MutedUser"
    assert mute.normalized_nickname == "muteduser"
    assert mute.operator_nickname == "Admin"
    assert mute.reason == "spam"
    assert is_nil(mute.expires_at)
  end

  test "creates a temporary mute and schedules expiry" do
    assert :ok = GlobalMutes.mute("TempMute", "Admin", nil, 60)

    mute = Repo.one!(GlobalMute)

    assert %DateTime{} = mute.expires_at

    assert_enqueued(
      worker: GlobalMuteExpiryWorker,
      queue: :maintenance,
      args: %{mute_id: mute.id}
    )
  end

  test "re-muting the same nickname reuses active row and replaces expiry" do
    assert :ok = GlobalMutes.mute("RepeatMute", "Admin", nil, 60)
    first = Repo.one!(GlobalMute)

    assert :ok = GlobalMutes.mute("repeatmute", "Admin2", "new reason", :permanent)
    second = Repo.one!(GlobalMute)

    assert second.id == first.id
    assert second.nickname == "repeatmute"
    assert second.operator_nickname == "Admin2"
    assert second.reason == "new reason"
    assert is_nil(second.expires_at)
    assert GlobalMutes.muted?("RepeatMute")
    assert all_enqueued(worker: GlobalMuteExpiryWorker, queue: :maintenance) == []
  end

  test "manual unmute revokes durable row, clears cache and cancels expiry" do
    assert :ok = GlobalMutes.mute("ManualMute", "Admin", nil, 60)
    mute = Repo.one!(GlobalMute)

    assert_enqueued(
      worker: GlobalMuteExpiryWorker,
      queue: :maintenance,
      args: %{mute_id: mute.id}
    )

    assert :ok = GlobalMutes.unmute("manualmute", "Admin")

    reloaded = Repo.get!(GlobalMute, mute.id)

    assert reloaded.revoked_at
    assert reloaded.revoked_by_nickname == "Admin"
    assert reloaded.revoke_reason == "manual"
    refute GlobalMutes.muted?("ManualMute")
    assert all_enqueued(worker: GlobalMuteExpiryWorker, queue: :maintenance) == []
  end

  test "expire_due materializes due temporary mutes" do
    now = DateTime.utc_now()
    past = DateTime.add(now, -120, :second)

    assert :ok = GlobalMutes.mute("DueMute", "Admin", nil, 60)
    mute = Repo.one!(GlobalMute)

    from(stored in GlobalMute, where: stored.id == ^mute.id)
    |> Repo.update_all(set: [expires_at: past])

    assert {:ok, {:expired, expired}} = GlobalMutes.expire_due(mute.id, now: now)

    assert expired.revoked_by_nickname == "system"
    assert expired.revoke_reason == "expired"
    refute GlobalMutes.muted?("DueMute")
  end
end
