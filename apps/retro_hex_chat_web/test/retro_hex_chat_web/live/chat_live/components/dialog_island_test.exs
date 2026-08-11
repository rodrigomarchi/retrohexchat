defmodule RetroHexChatWeb.ChatLive.Components.DialogIslandTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias Phoenix.LiveView.Socket
  alias RetroHexChatWeb.ChatLive.Components.DialogIsland

  defp socket, do: %Socket{}

  describe "mount/3" do
    test "a dialog starts knowing its id and holding what it declared" do
      {:ok, mounted} = DialogIsland.mount(socket(), "admin-turn", %{result: nil, loaded?: false})

      assert mounted.assigns.id == "admin-turn"
      assert mounted.assigns.result == nil
      assert mounted.assigns.loaded? == false
    end

    test "a dialog starts without a session, because the parent sends one" do
      {:ok, mounted} = DialogIsland.mount(socket(), "admin-turn", %{})

      assert Map.has_key?(mounted.assigns, :session)
      assert mounted.assigns.session == nil
    end
  end

  describe "update/2" do
    test "takes what the parent sends" do
      {:ok, mounted} = DialogIsland.mount(socket(), "d", %{})
      {:ok, updated} = DialogIsland.update(mounted, %{session: :a_session})

      assert updated.assigns.session == :a_session
    end
  end

  describe "load_once/3" do
    test "loads on the first update" do
      {:ok, mounted} = DialogIsland.mount(socket(), "d", %{loaded?: false})

      {:ok, updated} =
        DialogIsland.load_once(mounted, %{}, fn socket ->
          Phoenix.Component.assign(socket, snapshot: :read)
        end)

      assert updated.assigns.snapshot == :read
      assert updated.assigns.loaded?
    end

    test "does not load again on later updates" do
      {:ok, mounted} = DialogIsland.mount(socket(), "d", %{loaded?: false})
      test_pid = self()

      load = fn socket ->
        send(test_pid, :loaded)
        socket
      end

      {:ok, once} = DialogIsland.load_once(mounted, %{}, load)
      {:ok, _twice} = DialogIsland.load_once(once, %{session: :changed}, load)

      assert_received :loaded
      refute_received :loaded
    end

    test "still takes what the parent sends on a later update" do
      {:ok, mounted} = DialogIsland.mount(socket(), "d", %{loaded?: false})
      identity = & &1

      {:ok, once} = DialogIsland.load_once(mounted, %{}, identity)
      {:ok, twice} = DialogIsland.load_once(once, %{session: :changed}, identity)

      assert twice.assigns.session == :changed
    end

    test "a dialog already loaded when it first updates does not load" do
      {:ok, mounted} = DialogIsland.mount(socket(), "d", %{loaded?: true})
      test_pid = self()

      {:ok, _updated} =
        DialogIsland.load_once(mounted, %{}, fn socket ->
          send(test_pid, :loaded)
          socket
        end)

      refute_received :loaded
    end
  end
end
