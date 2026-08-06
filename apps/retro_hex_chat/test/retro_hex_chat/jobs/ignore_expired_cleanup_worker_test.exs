defmodule RetroHexChat.Jobs.IgnoreExpiredCleanupWorkerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.IgnoreList
  alias RetroHexChat.Chat.Schemas.IgnoreListEntry
  alias RetroHexChat.Jobs.IgnoreExpiredCleanupWorker
  alias RetroHexChat.Repo

  test "worker removes expired ignore entries and emits telemetry" do
    now = DateTime.utc_now()
    past = DateTime.add(now, -120, :second)
    future = DateTime.add(now, 300, :second)

    insert_registered_nick!("IgnoreWorker")
    insert_ignore_entry!("IgnoreWorker", "Expired", past)
    insert_ignore_entry!("IgnoreWorker", "Active", future)
    insert_ignore_entry!("IgnoreWorker", "Permanent", nil)

    attach_telemetry([:retro_hex_chat, :chat, :ignore_list, :cleanup, :stop])

    assert {:ok, summary} =
             IgnoreExpiredCleanupWorker.perform(%Oban.Job{
               args: %{"limit" => 10},
               attempt: 1,
               max_attempts: 3
             })

    assert summary.candidates == 1
    assert summary.deleted == 1
    assert IgnoreList.expired_entry_count(now: now) == 0
    assert Repo.get_by(IgnoreListEntry, ignored_nickname: "Expired") == nil
    assert Repo.get_by(IgnoreListEntry, ignored_nickname: "Active") != nil
    assert Repo.get_by(IgnoreListEntry, ignored_nickname: "Permanent") != nil

    assert_receive {:telemetry_event, [:retro_hex_chat, :chat, :ignore_list, :cleanup, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "chat"
    assert metadata.operation == "ignore_list_cleanup"
    assert metadata.result == "ok"
    assert metadata.candidates == 1
    assert metadata.deleted == 1
    assert metadata.oldest_expired_age_ms > 0
  end

  test "worker definition allows only three attempts" do
    changeset = IgnoreExpiredCleanupWorker.new(%{})

    assert Ecto.Changeset.get_change(changeset, :max_attempts) == 3
  end

  defp insert_registered_nick!(nickname) do
    Repo.insert_all("registered_nicks", [
      %{
        nickname: nickname,
        password_hash: Bcrypt.hash_pwd_salt("password"),
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    ])
  end

  defp insert_ignore_entry!(owner, nickname, expires_at) do
    %IgnoreListEntry{}
    |> IgnoreListEntry.changeset(%{
      owner_nickname: owner,
      ignored_nickname: nickname,
      ignore_type: "all",
      expires_at: expires_at
    })
    |> Repo.insert!()
  end

  defp attach_telemetry(event) do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      handler_id,
      [event],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end
end
