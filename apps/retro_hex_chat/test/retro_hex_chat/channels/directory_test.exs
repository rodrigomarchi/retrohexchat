defmodule RetroHexChat.Channels.DirectoryTest do
  @moduledoc """
  The channel directory `/list` reads.

  The regression these guard: listing channels used to make one synchronous
  `GenServer.call` per channel, so opening the dialog on a busy server meant N
  blocking round trips, each queued behind whatever that channel was doing.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  import ExUnit.Callbacks, only: [on_exit: 1]

  alias RetroHexChat.Channels.{Directory, Registry, Server, Supervisor}
  alias RetroHexChat.Commands.Autocomplete
  alias RetroHexChat.Services.Queries, as: ServiceQueries

  defp unique(prefix), do: "##{prefix}#{System.unique_integer([:positive])}"

  defp register_channel(name, opts \\ []) do
    {:ok, _} = ServiceQueries.insert_registered_channel(name, "Founder")

    ServiceQueries.update_registered_channel_settings(name,
      modes: Keyword.get(opts, :modes, ""),
      topic: Keyword.get(opts, :topic, "")
    )

    on_exit(fn ->
      case ServiceQueries.find_registered_channel(name) do
        nil -> :ok
        channel -> ServiceQueries.delete_registered_channel(channel)
      end
    end)

    name
  end

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

  describe "catalog/1" do
    test "a registered channel with nobody in it is still in the catalogue" do
      name = unique("coldreg")
      register_channel(name)

      entry = Enum.find(Directory.catalog(), &(&1.name == name))

      assert entry, "a channel that emptied stopped existing for whoever arrives next"
      refute entry.live?
      assert entry.member_count == 0
      assert entry.last_activity_at
    end

    test "a channel that is both running and registered appears once" do
      name = unique("bothreg")
      register_channel(name)
      start_channel(name)

      matches = Enum.filter(Directory.catalog(), &(&1.name == name))

      assert [entry] = matches
      assert entry.live?
    end

    # A registered channel keeps its process after the last person leaves, so a
    # live row with nobody in it is ordinary. The row still has to answer when
    # the room was last used, and that fact only exists in the table.
    test "a running registered channel carries its last activity too" do
      name = unique("livereg")
      register_channel(name)
      start_channel(name)

      entry = Enum.find(Directory.catalog(), &(&1.name == name))

      assert entry.live?
      assert entry.last_activity_at
    end

    # `:limit` is documented as the cap on the cold half, and a cap that a live
    # channel can eat is a different cap: the rows that reach the reader come
    # up short by however many registered rooms happen to be running.
    test "a running registered channel does not eat a cold slot", ctx do
      _ = ctx
      cold_a = unique("capcolda")
      cold_b = unique("capcoldb")
      live = unique("caplive")

      register_channel(cold_a)
      register_channel(cold_b)
      register_channel(live)
      start_channel(live)
      Server.join(live, "Alice")

      names =
        [limit: 2]
        |> Directory.catalog()
        |> Enum.reject(& &1.live?)
        |> Enum.map(& &1.name)

      assert length(names) == 2
    end

    test "live channels sort ahead of cold ones" do
      cold = unique("sortcold")
      live = unique("sortlive")
      register_channel(cold)
      start_channel(live)
      Server.join(live, "Alice")

      names = Directory.catalog() |> Enum.map(& &1.name)

      assert Enum.find_index(names, &(&1 == live)) < Enum.find_index(names, &(&1 == cold))
    end

    # The catalogue is the raw view; who may be told about a channel is
    # `Autocomplete.list_visible_channels/2`, exactly as it is for the live
    # half. What matters here is that a cold row carries the flags that
    # decision needs, decoded from the column instead of from a process.
    test "a cold row carries the modes stored against it" do
      secret = unique("coldsecret")
      private = unique("coldprivate")
      register_channel(secret, modes: "+s")
      register_channel(private, modes: "+p")

      rows = Map.new(Directory.catalog(), &{&1.name, &1})

      assert rows[secret].secret?
      refute rows[secret].private?
      assert rows[private].private?
      refute rows[private].secret?
    end

    test "the search term reaches the cold half too" do
      name = unique("coldsearch")
      register_channel(name, topic: "vintage hardware talk")

      by_name = Directory.catalog(search: String.trim_leading(name, "#"))
      by_topic = Directory.catalog(search: "vintage hardware")

      assert Enum.any?(by_name, &(&1.name == name))
      assert Enum.any?(by_topic, &(&1.name == name))
      refute Enum.any?(Directory.catalog(search: "nothing matches this"), &(&1.name == name))
    end

    test "every entry carries the same shape, live or cold" do
      cold = unique("shapecold")
      live = unique("shapelive")
      register_channel(cold)
      start_channel(live)

      keys =
        Directory.catalog()
        |> Enum.filter(&(&1.name in [cold, live]))
        |> Enum.map(&(&1 |> Map.keys() |> Enum.sort()))
        |> Enum.uniq()

      assert length(keys) == 1, "a cold row with a different shape breaks whoever renders both"
    end
  end
end
