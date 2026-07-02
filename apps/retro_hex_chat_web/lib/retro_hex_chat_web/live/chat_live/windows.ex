defmodule RetroHexChatWeb.ChatLive.Windows do
  @moduledoc """
  Desktop-window lifecycle helpers for the chat.

  Server-managed windows render only while their id is in the `open_windows`
  assign — the host mounts/unmounts the island. All other windows are always
  mounted and the window manager owns their visibility client-side, so opening
  them is purely a `window_command` push.

  `open/2` is the single opener every entry point uses (menu bar, start menu
  fallback, commands): it mounts the island when the id is managed and pushes
  the client command that opens/focuses the window either way — re-invoking
  focuses the existing window, never duplicates.
  """

  import Phoenix.Component, only: [update: 3]
  import Phoenix.LiveView, only: [push_event: 3]

  @managed MapSet.new(
             ~w(address-book alias auto-respond cheatsheet custom-menus flood-protection highlight notify-list perform sound-settings timers)
           )

  @doc "Whether the window's lifecycle is server-owned."
  @spec managed?(String.t()) :: boolean()
  def managed?(id), do: MapSet.member?(@managed, id)

  @doc "Open/focus a window: mount it if managed, then focus it client-side."
  @spec open(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket, id) do
    socket
    |> open_window(id)
    |> push_event("window_command", %{action: "open", id: id})
  end

  @doc "Add a managed window to `open_windows` (no-op for non-managed ids)."
  @spec open_window(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def open_window(socket, id) do
    if managed?(id) do
      update(socket, :open_windows, &MapSet.put(&1, id))
    else
      socket
    end
  end

  @doc "Remove a window from `open_windows` (unmounts a managed island)."
  @spec close_window(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def close_window(socket, id) do
    update(socket, :open_windows, &MapSet.delete(&1, id))
  end

  @doc "Whether a managed window is currently open (mounted)."
  @spec open?(Phoenix.LiveView.Socket.t(), String.t()) :: boolean()
  def open?(socket, id), do: MapSet.member?(socket.assigns.open_windows, id)
end
