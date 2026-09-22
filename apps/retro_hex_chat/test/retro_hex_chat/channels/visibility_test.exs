defmodule RetroHexChat.Channels.VisibilityTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.{Server, Supervisor, Visibility}
  alias RetroHexChat.Services.Queries, as: ServiceQueries

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

  describe "nameable?/1 for a channel with no process" do
    # A registered channel that nobody has joined since the node started has no
    # process at all, and asking one that is not there used to answer "not
    # nameable" — so a link to a quiet public room refused to say its own name.
    setup do
      name = "#visreg#{System.unique_integer([:positive])}"
      {:ok, _} = ServiceQueries.insert_registered_channel(name, "Founder")

      on_exit(fn ->
        case ServiceQueries.find_registered_channel(name) do
          nil -> :ok
          channel -> ServiceQueries.delete_registered_channel(channel)
        end
      end)

      %{name: name}
    end

    test "a registered public channel is nameable", %{name: name} do
      assert Visibility.nameable?(name)
    end

    test "a registered secret channel is not", %{name: name} do
      ServiceQueries.update_registered_channel_settings(name, modes: "+s")

      refute Visibility.nameable?(name)
    end

    test "a registered invite-only channel is not", %{name: name} do
      ServiceQueries.update_registered_channel_settings(name, modes: "+i")

      refute Visibility.nameable?(name)
    end

    test "a channel that was never registered and is not running is not" do
      refute Visibility.nameable?("#neverexisted#{System.unique_integer([:positive])}")
    end
  end
end
