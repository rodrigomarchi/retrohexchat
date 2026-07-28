defmodule RetroHexChat.Channels.DirectoryTest do
  @moduledoc """
  The channel directory `/list` reads.

  The regression these guard: listing channels used to make one synchronous
  `GenServer.call` per channel, so opening the dialog on a busy server meant N
  blocking round trips, each queued behind whatever that channel was doing.
  """
  use ExUnit.Case, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.{Directory, Registry, Server, Supervisor}
  alias RetroHexChat.Commands.Autocomplete

  defp unique(prefix), do: "##{prefix}#{System.unique_integer([:positive])}"

  defp start_channel(name) do
    case Registry.lookup(name) do
      {:ok, pid} -> pid
      {:error, :not_found} -> start_supervised_channel(name)
    end
  end

  defp start_supervised_channel(name) do
    {:ok, pid} = Supervisor.start_child(name)

    on_exit(fn ->
      if Process.alive?(pid), do: Supervisor.stop_child(RetroHexChat.Channels.Supervisor, pid)
    end)

    pid
  end

  describe "all/0" do
    test "a channel appears as soon as it starts, before anyone acts on it" do
      name = unique("dirnew")
      start_channel(name)

      assert Enum.any?(Directory.all(), &(&1.name == name)),
             "a channel that published nothing would be invisible to /list"
    end

    test "the member count follows joins and parts" do
      name = unique("dircount")
      start_channel(name)

      Server.join(name, "Alice")
      Server.join(name, "Bob")

      assert find(name).member_count == 2

      Server.part(name, "Bob", nil)

      assert find(name).member_count == 1
    end

    test "the topic follows a topic change" do
      name = unique("dirtopic")
      start_channel(name)
      Server.join(name, "Owner")

      Server.set_topic(name, "Owner", "the new topic")

      assert find(name).topic == "the new topic"
    end

    test "mode flags follow a mode change" do
      name = unique("dirmode")
      start_channel(name)
      Server.join(name, "Owner")

      refute find(name).secret?

      Server.set_mode(name, "Owner", "+s", [])

      assert find(name).secret?
    end
  end

  describe "reading the directory does not talk to the channels" do
    test "listing never sends a message to a channel process" do
      name = unique("dirquiet")
      pid = start_channel(name)
      Server.join(name, "Alice")

      # A channel that receives nothing during the read has its message queue
      # untouched; the old implementation put one call in it per channel.
      {:messages, before_queue} = Process.info(pid, :messages)

      Autocomplete.list_visible_channels([])
      Directory.all()

      {:messages, after_queue} = Process.info(pid, :messages)

      assert before_queue == after_queue
    end
  end

  describe "search/1" do
    test "matches on name" do
      name = unique("dirsearchable")
      start_channel(name)

      assert Enum.any?(Directory.search("dirsearchable"), &(&1.name == name))
    end

    test "matches on topic, case-insensitively" do
      name = unique("dirtopicsearch")
      start_channel(name)
      Server.join(name, "Owner")
      Server.set_topic(name, "Owner", "Elixir And Otp")

      assert Enum.any?(Directory.search("elixir and"), &(&1.name == name))
    end

    test "a term nothing matches yields nothing" do
      start_channel(unique("dirnomatch"))

      assert Directory.search("zzz-no-such-channel-zzz") == []
    end

    test "a blank term does not filter" do
      name = unique("dirblank")
      start_channel(name)

      # Deliberately not a count comparison: the registry is global and the CI
      # runs another test worker in parallel, so any assertion over the whole
      # directory's size races channels being created elsewhere.
      assert Enum.any?(Directory.search("   "), &(&1.name == name))
      assert Enum.any?(Directory.search(""), &(&1.name == name))
    end
  end

  describe "visibility rules" do
    test "a secret channel is hidden from non-members but visible to members" do
      name = unique("dirsecret")
      start_channel(name)
      Server.join(name, "Owner")
      Server.set_mode(name, "Owner", "+s", [])

      refute Enum.any?(Autocomplete.list_visible_channels([]), &(&1.name == name))
      assert Enum.any?(Autocomplete.list_visible_channels([name]), &(&1.name == name))
    end

    test "a private channel shows only as a placeholder to non-members" do
      name = unique("dirprivate")
      start_channel(name)
      Server.join(name, "Owner")
      Server.set_mode(name, "Owner", "+p", [])

      visible = Autocomplete.list_visible_channels([])

      refute Enum.any?(visible, &(&1.name == name))
      assert Enum.any?(visible, &(&1.name == "Prv"))
    end
  end

  defp find(name), do: Enum.find(Directory.all(), &(&1.name == name))
end
