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

  test "loads unjoined visible channels by popularity from the channel directory" do
    popular = unique("sidebarpopular")
    quieter = unique("sidebarquiet")
    joined = unique("sidebarjoined")

    start_channel(popular)
    start_channel(quieter)
    start_channel(joined)

    Enum.each(["Alice", "Bob", "Carol"], fn nick ->
      assert {:ok, _state} = Server.join(popular, nick)
    end)

    assert {:ok, _state} = Server.join(quieter, "Dave")
    assert {:ok, _state} = Server.join(joined, "Viewer")

    session =
      "Viewer"
      |> Session.new()
      |> Session.add_channel(joined)

    socket = session |> socket_with_session() |> ConversationsReadModel.load_popular_channels()

    names = Enum.map(socket.assigns.popular_channels, & &1.name)

    assert popular in names
    assert quieter in names
    refute joined in names

    assert Enum.find_index(names, &(&1 == popular)) <
             Enum.find_index(names, &(&1 == quieter))
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

  defp socket_with_session(session) do
    %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, session: session}}
  end
end
