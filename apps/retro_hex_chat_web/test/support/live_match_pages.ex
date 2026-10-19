defmodule RetroHexChatWeb.LiveMatchPages do
  @moduledoc """
  The two pages of a match being played, without a browser: a process per
  player that says it is playing over a session, as `P2PLive` does, and stays
  until the test is over.
  """
  import ExUnit.Assertions
  import ExUnit.Callbacks

  alias Ecto.Adapters.SQL.Sandbox
  alias RetroHexChat.Games.Activity
  alias RetroHexChat.Repo

  @doc "Each of `nicknames` plays `game_id` over the session `token`."
  @spec playing([String.t()], String.t(), String.t()) :: :ok
  def playing(nicknames, game_id, token) do
    test = self()

    for nickname <- nicknames do
      pid =
        spawn(fn ->
          receive do
            :go -> :ok = Activity.playing(nickname, game_id, token)
          end

          send(test, {:playing, nickname})
          Process.sleep(:infinity)
        end)

      # The page reads the session it plays over.
      Sandbox.allow(Repo, test, pid)
      send(pid, :go)
      assert_receive {:playing, ^nickname}
      on_exit(fn -> Process.exit(pid, :kill) end)
    end

    :ok
  end
end
