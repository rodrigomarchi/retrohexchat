defmodule RetroHexChat.Channels.VisibilityTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.{Server, Supervisor, Visibility}

  defp channel!(suffix) do
    name = "#vis#{suffix}#{System.unique_integer([:positive])}"
    {:ok, pid} = Supervisor.start_child(name)
    on_exit(fn -> if Process.alive?(pid), do: Supervisor.stop_child(pid) end)

    name
  end

  defp joined(channel, nickname) do
    {:ok, _state} = Server.join(channel, nickname)
    channel
  end

  # The first person to join a channel owns it, so they are the one who can
  # make it secret.
  defp secret(channel, owner) do
    :ok = Server.set_mode(channel, owner, "+s")
    channel
  end

  test "a channel the person is in is told about" do
    channel = channel!("pub") |> joined("alice")

    assert Visibility.channels_of("alice", []) |> Enum.member?(channel)
  end

  test "a channel the person is not in is not" do
    channel = channel!("other") |> joined("bob")

    refute Visibility.channels_of("alice", []) |> Enum.member?(channel)
  end

  test "however the nickname was typed" do
    channel = channel!("case") |> joined("Alice")

    assert Visibility.channels_of("alice", []) |> Enum.member?(channel)
    assert Visibility.channels_of("ALICE", []) |> Enum.member?(channel)
  end

  # A secret channel's existence is what is being protected, not just its
  # membership, so it is withheld from somebody who is not already in it.
  test "a secret channel is withheld from someone outside it" do
    channel = channel!("sec") |> joined("alice") |> secret("alice")

    refute Visibility.channels_of("alice", []) |> Enum.member?(channel)
  end

  test "and told to someone already inside it, who learns nothing new" do
    channel = channel!("secin") |> joined("alice") |> secret("alice")

    assert Visibility.channels_of("alice", [channel]) |> Enum.member?(channel)
  end

  test "the answer is alphabetical" do
    names = Visibility.channels_of("nobody-at-all", [])

    assert names == Enum.sort(names)
  end
end
