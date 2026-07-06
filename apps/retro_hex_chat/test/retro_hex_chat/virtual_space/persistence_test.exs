defmodule RetroHexChat.VirtualSpace.PersistenceTest do
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.VirtualSpace.{Queries, Registry, SessionServer, Supervisor}

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :virtual_space_step_ms, 0)
    on_exit(fn -> Application.delete_env(:retro_hex_chat, :virtual_space_step_ms) end)
    :ok
  end

  defp start_space do
    creator = insert(:registered_nick)

    {:ok, session} =
      Queries.insert_session(%{
        token: "persist-#{System.unique_integer([:positive])}",
        channel_name: "#retro",
        creator_id: creator.id,
        creator_nick: creator.nickname,
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    {:ok, _pid} = Supervisor.start_child(session.token)
    %{token: session.token, creator: creator}
  end

  defp stop(token) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.stop(pid, :normal)
      _ -> :ok
    end
  end

  test "leave persists position to metadata; a fresh process restores it on rejoin" do
    ctx = start_space()
    key = "registered:#{ctx.creator.id}"

    {:ok, _} =
      SessionServer.join(ctx.token, %{user_id: ctx.creator.id, nickname: ctx.creator.nickname})

    :ok = SessionServer.input(ctx.token, key, %{seq: 1, dx: 1, dy: 0})
    :ok = SessionServer.input(ctx.token, key, %{seq: 2, dx: 0, dy: 1})

    {:ok, state} = SessionServer.get_state(ctx.token)
    %{x: x, y: y} = state.participants[key]

    SessionServer.leave(ctx.token, key)
    # Leave is a cast; wait for the metadata write to land.
    wait_until(fn ->
      case Queries.get_session_by_token(ctx.token).metadata do
        %{"positions" => positions} -> Map.has_key?(positions, key)
        _ -> false
      end
    end)

    # Simulate a process restart: no hot state survives.
    stop(ctx.token)
    {:ok, pid} = Supervisor.start_child(ctx.token)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)

    {:ok, %{participant: restored}} =
      SessionServer.join(ctx.token, %{user_id: ctx.creator.id, nickname: ctx.creator.nickname})

    assert {restored.x, restored.y} == {x, y}
  end

  defp wait_until(fun, retries \\ 50) do
    cond do
      fun.() -> :ok
      retries == 0 -> flunk("condition never became true")
      true -> Process.sleep(10) && wait_until(fun, retries - 1)
    end
  end
end
