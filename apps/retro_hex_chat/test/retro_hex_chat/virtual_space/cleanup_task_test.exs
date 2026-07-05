defmodule RetroHexChat.VirtualSpace.CleanupTaskTest do
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.VirtualSpace.{CleanupTask, Queries}

  @moduletag :integration

  defp insert_space(attrs) do
    creator = insert(:registered_nick)

    base = %{
      token: "space-#{System.unique_integer([:positive])}",
      channel_name: "#retro",
      creator_id: creator.id,
      creator_nick: creator.nickname
    }

    {:ok, session} = Queries.insert_session(Map.merge(base, attrs))
    session
  end

  describe "run_cleanup/0" do
    test "expires overdue sessions without a live process" do
      overdue =
        insert_space(%{expires_at: DateTime.add(DateTime.utc_now(), -60, :second)})

      alive =
        insert_space(%{expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)})

      assert {:ok, count} = CleanupTask.run_cleanup()

      assert count >= 1
      assert Queries.get_session_by_token(overdue.token).status == "expired"
      assert Queries.get_session_by_token(alive.token).status == "pending"
    end

    test "skips overdue sessions whose process is still registered" do
      overdue =
        insert_space(%{expires_at: DateTime.add(DateTime.utc_now(), -60, :second)})

      # A registered process owns the expiry of its own session; simulate one
      # so the cleanup must leave the row untouched.
      parent = self()

      holder =
        spawn_link(fn ->
          Registry.register(RetroHexChat.VirtualSpace.SessionRegistry, overdue.token, nil)
          send(parent, :registered)

          receive do
            :release -> :ok
          end
        end)

      assert_receive :registered

      {:ok, _count} = CleanupTask.run_cleanup()

      assert Queries.get_session_by_token(overdue.token).status == "pending"
      send(holder, :release)
    end
  end
end
