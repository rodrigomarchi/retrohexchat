defmodule RetroHexChat.Services.NickServRestoreTest do
  # Async on purpose: the sandbox is in manual mode, so only this test's own
  # process may reach the database — exactly as in the running chat, where the
  # reconnecting LiveView holds the connection and NickServ holds none of its.
  use RetroHexChat.DataCase, async: true

  @moduletag :unit

  alias RetroHexChat.Services.{NickServ, Queries}

  setup do
    server = start_supervised!({NickServ, name: nil})
    %{server: server}
  end

  defp nick, do: "Back#{rem(System.unique_integer([:positive]), 100_000)}"

  test "a registered nickname is identified again", %{server: server} do
    nickname = nick()
    {:ok, _} = Queries.insert_registered_nick(nickname, "secret123")

    :ok = NickServ.restore_identified(nickname, server)

    assert NickServ.identified?(nickname, server)
  end

  test "a nickname nobody registered is not", %{server: server} do
    nickname = nick()

    :ok = NickServ.restore_identified(nickname, server)

    refute NickServ.identified?(nickname, server)
  end

  test "NickServ itself never reaches for the database to restore", %{server: server} do
    nickname = nick()
    {:ok, _} = Queries.insert_registered_nick(nickname, "secret123")
    ref = Process.monitor(server)

    :ok = NickServ.restore_identified(nickname, server)
    assert NickServ.identified?(nickname, server)

    refute_received {:DOWN, ^ref, :process, _pid, _reason}
  end
end
