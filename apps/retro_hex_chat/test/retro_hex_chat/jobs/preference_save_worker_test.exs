defmodule RetroHexChat.Jobs.PreferenceSaveWorkerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.{IgnoreList, InputHistory, PreferencePersistence}
  alias RetroHexChat.Jobs.PreferenceSaveWorker
  alias RetroHexChat.Services.NickServ

  test "coalesces repeated snapshots and applies the latest one" do
    owner = owner("PrefIn")
    attach_telemetry()

    assert :ok =
             PreferencePersistence.enqueue(owner, :input_history, %{
               entries: ["first"],
               recent_commands: []
             })

    assert :ok =
             PreferencePersistence.enqueue(owner, :input_history, %{
               entries: ["second"],
               recent_commands: ["join"]
             })

    assert_enqueued(
      worker: PreferenceSaveWorker,
      queue: :persistence,
      args: %{owner_nickname: owner, preference_type: "input_history"}
    )

    request = PreferencePersistence.get_request(owner, "input_history")

    assert request.revision == 2
    assert request.status == "pending"
    assert request.payload["entries"] == ["second"]

    assert {:ok, :applied} =
             PreferenceSaveWorker.perform(%Oban.Job{
               args: %{"owner_nickname" => owner, "preference_type" => "input_history"},
               attempt: 1,
               max_attempts: 5
             })

    assert {:ok, loaded} = InputHistory.load(owner)
    assert loaded.entries == ["second"]
    assert loaded.recent_commands == ["join"]

    request = PreferencePersistence.get_request(owner, "input_history")

    assert request.status == "applied"
    assert request.applied_revision == 2

    assert_receive {:telemetry_event, [:retro_hex_chat, :persistence, :save, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "persistence"
    assert metadata.operation == "save"
    assert metadata.preference_type == "input_history"
    assert metadata.result == "ok"
  end

  test "hydrates enum values before calling domain save functions" do
    owner = owner("PrefIg")

    assert :ok =
             PreferencePersistence.enqueue(owner, :ignore_list, %{
               entries: [
                 %{
                   nickname: "Noisy",
                   ignore_type: :messages,
                   expires_at: nil,
                   created_at: DateTime.utc_now()
                 }
               ]
             })

    request = PreferencePersistence.get_request(owner, "ignore_list")
    assert get_in(request.payload, ["entries", Access.at(0), "ignore_type"]) == "messages"

    assert {:ok, :applied} =
             PreferenceSaveWorker.perform(%Oban.Job{
               args: %{"owner_nickname" => owner, "preference_type" => "ignore_list"},
               attempt: 1,
               max_attempts: 5
             })

    assert {:ok, loaded} = IgnoreList.load(owner)
    [entry] = loaded.entries

    assert entry.nickname == "Noisy"
    assert entry.ignore_type == :messages
  end

  test "marks failed requests and returns error for retry" do
    owner = owner("PrefFl")

    assert :ok =
             PreferencePersistence.enqueue(owner, :flood_protection, %{
               flood_threshold: -1,
               flood_window_seconds: 15,
               auto_ignore_duration_seconds: 300,
               spam_threshold: 3,
               spam_window_seconds: 10
             })

    assert {:error, %Ecto.Changeset{}} =
             PreferenceSaveWorker.perform(%Oban.Job{
               args: %{"owner_nickname" => owner, "preference_type" => "flood_protection"},
               attempt: 1,
               max_attempts: 5
             })

    request = PreferencePersistence.get_request(owner, "flood_protection")

    assert request.status == "failed"
    assert request.attempts == 1
    assert request.last_error == "changeset_error"
  end

  defp owner(prefix) do
    suffix =
      [System.unique_integer([:positive])]
      |> :erlang.phash2(100_000)
      |> Integer.to_string()

    owner = String.slice(prefix <> suffix, 0, 16)
    {:ok, _message} = NickServ.register(owner, "pass123")
    owner
  end

  defp attach_telemetry do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      handler_id,
      [
        [:retro_hex_chat, :persistence, :save, :stop],
        [:retro_hex_chat, :observability, :operation, :stop]
      ],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end
end
