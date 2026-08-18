defmodule RetroHexChatWeb.ChatLive.ConversationsReadModelTest do
  use ExUnit.Case, async: false

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.{Registry, Server, Supervisor}
  alias RetroHexChatWeb.ChatLive.ConversationsReadModel

  @moduletag :integration

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

  defp listing(entries) do
    Enum.map(entries, fn {name, user_count, extra} ->
      Map.merge(
        %{name: name, topic: nil, user_count: user_count, joined?: false, modes: ""},
        Map.new(extra)
      )
    end)
  end

  # The selection is tested on a known listing: the channel directory is global
  # to the suite, so "is this channel among the top ten?" cannot be asserted
  # against whatever channels the other tests left running.
  describe "popular_channels/2" do
    test "orders unjoined public channels by popularity" do
      channels = listing([{"#quiet", 1, []}, {"#busy", 9, []}, {"#middling", 4, []}])

      assert Enum.map(ConversationsReadModel.popular_channels(channels, []), & &1.name) ==
               ["#busy", "#middling", "#quiet"]
    end

    test "drops the channels this session already joined" do
      channels = listing([{"#joined", 9, []}, {"#open", 1, []}])

      assert Enum.map(ConversationsReadModel.popular_channels(channels, ["#joined"]), & &1.name) ==
               ["#open"]
    end

    test "drops private placeholders — they are not a name anyone can join" do
      channels = listing([{"Prv", 9, []}, {"#open", 1, []}])

      assert Enum.map(ConversationsReadModel.popular_channels(channels, []), & &1.name) ==
               ["#open"]
    end

    test "drops invite-only and keyed channels — one click cannot get you in" do
      channels =
        listing([
          {"#invite", 9, [invite_only?: true]},
          {"#keyed", 8, [modes: "+k"]},
          {"#open", 1, []}
        ])

      assert Enum.map(ConversationsReadModel.popular_channels(channels, []), & &1.name) ==
               ["#open"]
    end

    test "shows at most ten suggestions" do
      channels = listing(for n <- 1..15, do: {"#c#{n}", n, []})

      assert length(ConversationsReadModel.popular_channels(channels, [])) == 10
    end
  end

  describe "channel activity order" do
    test "touch_channel_activity/2 records monotonic activity per channel" do
      socket =
        "Viewer"
        |> Session.new()
        |> socket_with_session()
        |> ConversationsReadModel.touch_channel_activity("#one")
        |> ConversationsReadModel.touch_channel_activity("#two")
        |> ConversationsReadModel.touch_channel_activity("#one")

      assert socket.assigns.channel_activity_sequence == 3
      assert socket.assigns.channel_activity_order == %{"#one" => 3, "#two" => 2}
    end

    test "drop_channel_activity/2 removes a parted channel without rewinding the sequence" do
      socket =
        "Viewer"
        |> Session.new()
        |> socket_with_session()
        |> ConversationsReadModel.touch_channel_activity("#one")
        |> ConversationsReadModel.touch_channel_activity("#two")
        |> ConversationsReadModel.drop_channel_activity("#one")

      assert socket.assigns.channel_activity_sequence == 2
      assert socket.assigns.channel_activity_order == %{"#two" => 2}
    end
  end

  describe "load_popular_channels/1" do
    test "reads the live channel directory and leaves out the joined ones" do
      popular = unique("sidebarpopular")
      joined = unique("sidebarjoined")

      start_channel(popular)
      start_channel(joined)

      Enum.each(["Alice", "Bob", "Carol"], fn nick ->
        assert {:ok, _state} = Server.join(popular, nick)
      end)

      assert {:ok, _state} = Server.join(joined, "Viewer")

      session =
        "Viewer"
        |> Session.new()
        |> Session.add_channel(joined)

      socket = session |> socket_with_session() |> ConversationsReadModel.load_popular_channels()

      names = Enum.map(socket.assigns.popular_channels, & &1.name)
      counts = Enum.map(socket.assigns.popular_channels, & &1.user_count)

      # Which channels make the top ten depends on every channel the suite has
      # running, so assert the contract rather than a membership: the directory
      # was read, the joined channel is out, and the rest is ordered and capped.
      refute names == []
      refute joined in names
      assert Enum.all?(names, &String.starts_with?(&1, "#"))
      assert counts == Enum.sort(counts, :desc)
      assert length(names) <= 10
    end

    test "does not offer private placeholders as joinable popular channels" do
      private = unique("sidebarprivate")

      start_channel(private)
      assert {:ok, _state} = Server.join(private, "Owner")
      assert :ok = Server.set_mode(private, "Owner", "+p", [])

      socket =
        "Viewer"
        |> Session.new()
        |> socket_with_session()
        |> ConversationsReadModel.load_popular_channels()

      refute Enum.any?(socket.assigns.popular_channels, fn channel ->
               not String.starts_with?(channel.name, "#")
             end)
    end

    test "does not offer restricted channels as one-click popular suggestions" do
      invite_only = unique("sidebarinvite")
      keyed = unique("sidebarkey")

      start_channel(invite_only)
      start_channel(keyed)

      assert {:ok, _state} = Server.join(invite_only, "Owner")
      assert :ok = Server.set_mode(invite_only, "Owner", "+i", [])
      assert {:ok, _state} = Server.join(keyed, "Owner")
      assert :ok = Server.set_mode(keyed, "Owner", "+k", ["secret"])

      socket =
        "Viewer"
        |> Session.new()
        |> socket_with_session()
        |> ConversationsReadModel.load_popular_channels()

      names = Enum.map(socket.assigns.popular_channels, & &1.name)

      refute invite_only in names
      refute keyed in names
    end
  end

  defp socket_with_session(session) do
    %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, session: session}}
  end
end
