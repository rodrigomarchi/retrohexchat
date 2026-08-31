defmodule RetroHexChat.Jobs.OpenLobbyExpiryWorkerTest do
  @moduledoc """
  The sweep that bounds how long an unclaimed match link is a way in.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Jobs.OpenLobbyExpiryWorker
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Queries
  alias RetroHexChat.Services.Queries, as: ServiceQueries

  test "the worker closes unclaimed match links and reports what it did" do
    creator = registered_nick!("OpenExp#{unique()}")
    dead = open_lobby!(creator.id, -1_000)
    alive = open_lobby!(creator.id, 60_000)

    attach_telemetry([:retro_hex_chat, :lobby, :open_expiry, :stop])

    assert {:ok, summary} = OpenLobbyExpiryWorker.perform(%Oban.Job{args: %{"limit" => 10}})
    assert summary == %{candidates: 1, expired: 1, skipped: 0, remaining: 0}

    assert Queries.get_session_by_token(dead.token).status == "expired"
    assert Queries.get_session_by_token(dead.token).closed_reason == "open_lobby_unclaimed"
    assert Queries.get_session_by_token(alive.token).status == "open"

    assert_receive {:telemetry_event, [:retro_hex_chat, :lobby, :open_expiry, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "lobby"
    assert metadata.operation == "open_expiry"
    assert metadata.result == "ok"
    assert metadata.open_lobby_candidates == 1
    assert metadata.open_lobby_expired == 1
    assert metadata.open_lobby_remaining == 0
  end

  test "running the sweep twice changes nothing the second time" do
    creator = registered_nick!("OpenIdem#{unique()}")
    dead = open_lobby!(creator.id, -1_000)

    assert {:ok, %{expired: 1}} = OpenLobbyExpiryWorker.perform(%Oban.Job{args: %{}})

    assert {:ok, %{candidates: 0, expired: 0}} =
             OpenLobbyExpiryWorker.perform(%Oban.Job{args: %{}})

    closed = Queries.get_session_by_token(dead.token)
    assert closed.status == "expired"
  end

  test "a claimed lobby is never a candidate" do
    creator = registered_nick!("OpenClm#{unique()}")
    claimer = registered_nick!("OpenClc#{unique()}")
    session = open_lobby!(creator.id, 60_000)

    assert {:ok, _claimed} = Lobby.claim_open_session(session.token, claimer.id)

    assert Queries.list_expired_open_sessions(DateTime.add(DateTime.utc_now(), 1, :hour)) == []
  end

  test "the sweep is bounded, and says what it left behind" do
    creator = registered_nick!("OpenLim#{unique()}")
    for _ <- 1..3, do: open_lobby!(creator.id, -1_000)

    assert {:ok, summary} = OpenLobbyExpiryWorker.perform(%Oban.Job{args: %{"limit" => 2}})
    assert summary.candidates == 2
    assert summary.expired == 2
    assert summary.remaining == 1
  end

  defp open_lobby!(creator_id, expires_in_ms) do
    {:ok, %{session: session}} =
      Lobby.create_open_session(creator_id, expires_in_ms: expires_in_ms)

    session
  end

  defp registered_nick!(nickname) do
    {:ok, nick} = ServiceQueries.insert_registered_nick(nickname, "secret123")
    nick
  end

  defp unique, do: System.unique_integer([:positive]) |> rem(10_000)

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
