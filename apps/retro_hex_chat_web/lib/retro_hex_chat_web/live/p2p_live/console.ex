defmodule RetroHexChatWeb.P2PLive.Console do
  @moduledoc """
  The P2P session's console window on this page: which section it shows
  (call, files, games, stats) and its size — the mini call in the corner, or
  the console where it was — told to the page's window manager.
  """

  alias Phoenix.LiveView.Socket
  alias RetroHexChatWeb.P2PLive.SessionStatus

  @call_window_id "p2p-call"
  @p2p_console_width 640
  @p2p_console_height 430
  @p2p_console_x 448
  @p2p_console_y 72

  @doc "Shows `section` in the console; leaving the call section restores a mini call to the console's size."
  @spec open(Socket.t(), term()) :: Socket.t()
  def open(socket, section) do
    section = normalize_console_section(section)

    case socket.assigns.p2p_session do
      nil ->
        socket

      p2p ->
        was_mini? = Map.get(p2p, :call_mini, false)

        p2p =
          if section == "call" do
            p2p
          else
            Map.put(p2p, :call_mini, false)
          end

        socket
        |> SessionStatus.put_p2p(Map.put(p2p, :console_section, section))
        |> maybe_expand_p2p_console(section, was_mini?)
    end
  end

  defp normalize_console_section(section) when section in ~w(call files games stats), do: section

  defp normalize_console_section(section) when is_atom(section),
    do: normalize_console_section(Atom.to_string(section))

  defp normalize_console_section(_section), do: "call"

  defp maybe_expand_p2p_console(socket, "call", _was_mini?), do: socket

  defp maybe_expand_p2p_console(socket, _section, true), do: push_call_geometry(socket, false)

  defp maybe_expand_p2p_console(socket, _section, false), do: socket

  # The mini call is a size, and a size is the window manager's. This page has
  # one of its own — the session is a Win98 desktop with the call window on it —
  # so the command goes straight to it. Handing it to the chat instead is what
  # makes mini mode a checkbox that changes nothing: the chat's window manager
  # does not hold this call.
  # The mini window remembers where the console was, maximized included, and
  # leaving it puts the console back there; the default size is the fallback.
  @doc "Shrinks the call window to the mini call in the corner (`true`), or puts the console back where it was (`false`)."
  @spec push_call_geometry(Socket.t(), boolean()) :: Socket.t()
  def push_call_geometry(socket, true) do
    push_window_geometry(socket, "set_geometry", %{
      width: 300,
      height: 236,
      anchor: "bottom_right",
      margin: 16,
      remember: true
    })
  end

  def push_call_geometry(socket, false) do
    push_window_geometry(socket, "restore_geometry", %{
      width: @p2p_console_width,
      height: @p2p_console_height,
      x: @p2p_console_x,
      y: @p2p_console_y
    })
  end

  defp push_window_geometry(socket, action, geometry) do
    Phoenix.LiveView.push_event(
      socket,
      "window_command",
      geometry |> Map.put(:action, action) |> Map.put(:id, @call_window_id)
    )
  end
end
