defmodule RetroHexChat.Jobs.BotGreetingPruneWorkerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Bots.BotGreeting
  alias RetroHexChat.Bots.Queries
  alias RetroHexChat.Jobs.BotGreetingPruneWorker
  alias RetroHexChat.Repo

  setup do
    {:ok, bot} =
      Queries.create_bot(%{name: "PruneBot", nickname: "PruneBot", created_by: "admin"})

    {:ok, bot: bot}
  end

  test "forgets a long absence and keeps a recent one", %{bot: bot} do
    :first_time = Queries.record_greeting(bot.id, "#lobby", "recent", 3600)
    :first_time = Queries.record_greeting(bot.id, "#lobby", "ancient", 3600)
    age_greeting(bot.id, "ancient", 200)

    attach_telemetry([:retro_hex_chat, :bots, :greetings, :prune, :stop])

    assert {:ok, summary} =
             BotGreetingPruneWorker.perform(%Oban.Job{
               args: %{"limit" => 10},
               attempt: 1,
               max_attempts: 3
             })

    assert summary.candidates == 1
    assert summary.deleted == 1
    assert Repo.get_by(BotGreeting, nickname: "ancient") == nil
    assert Repo.get_by(BotGreeting, nickname: "recent") != nil

    assert_receive {:telemetry_event, [:retro_hex_chat, :bots, :greetings, :prune, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "bots"
    assert metadata.result == "ok"
    assert metadata.candidates == 1
    assert metadata.deleted == 1
  end

  test "somebody forgotten is announced again", %{bot: bot} do
    :first_time = Queries.record_greeting(bot.id, "#lobby", "ancient", 3600)
    age_greeting(bot.id, "ancient", 200)

    {:ok, _} =
      BotGreetingPruneWorker.perform(%Oban.Job{args: %{}, attempt: 1, max_attempts: 3})

    assert :first_time == Queries.record_greeting(bot.id, "#lobby", "ancient", 3600)
  end

  test "worker definition allows only three attempts" do
    changeset = BotGreetingPruneWorker.new(%{})

    assert Ecto.Changeset.get_change(changeset, :max_attempts) == 3
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

  defp age_greeting(bot_id, nickname, days) do
    when_ = DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)

    BotGreeting
    |> Repo.get_by(bot_id: bot_id, nickname: nickname)
    |> Ecto.Changeset.change(greeted_at: when_)
    |> Repo.update!()
  end
end
