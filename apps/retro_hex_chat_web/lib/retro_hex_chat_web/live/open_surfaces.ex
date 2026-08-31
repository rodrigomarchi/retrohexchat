defmodule RetroHexChatWeb.Live.OpenSurfaces do
  @moduledoc """
  What this person already has open, for the screens that draw a way in.

  Three screens offer "open in a tab" — the call badge, the space picker and
  the P2P starting room — and each of them is wrong about it in the same way if
  it does not know: the tab may already exist, and opening a second one is not
  a neutral act. A second P2P tab *moves the session into it*, which is the
  takeover contract firing for somebody who only wanted to look at what they
  already had.

  The answer comes from `RetroHexChat.Surfaces`, which monitors every surface
  process, and it arrives by subscription rather than by asking: a screen that
  polled would be right only at the moment it drew.

  Attached rather than inherited because the three screens have nothing else in
  common — one is the chat, and two are surfaces that the chat also renders
  inside itself. A behaviour would have made them relatives to share four lines.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1]

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Surfaces

  @doc """
  Start reading `nickname`'s open set into `@open_surface_paths`.

  Safe on a disconnected mount: the set is empty there, which is the same thing
  it says on a page that has nothing open, and the dead render offers the plain
  "open in a tab" — the honest default when nothing is known yet.
  """
  @spec attach(Socket.t(), String.t() | nil) :: Socket.t()
  def attach(socket, nickname) when is_binary(nickname) and nickname != "" do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Surfaces.topic(nickname))
    end

    socket
    |> assign(open_surface_paths: paths(socket, nickname))
    |> attach_hook(:open_surfaces, :handle_info, &changed/2)
  end

  def attach(socket, _nickname), do: assign(socket, open_surface_paths: MapSet.new())

  @doc """
  Whether `path` is one of the addresses this person has open.

  Takes the set and not the socket on purpose: inside a template `@socket`
  carries no assigns at all, so a version that read them there would answer
  "nothing is open" forever, in silence, and only in the place it is actually
  used.
  """
  @spec open?(MapSet.t(String.t()), String.t() | nil) :: boolean()
  def open?(%MapSet{} = paths, path) when is_binary(path), do: MapSet.member?(paths, path)
  def open?(_paths, _path), do: false

  defp changed({:surfaces_changed, surfaces}, socket) do
    {:halt, assign(socket, open_surface_paths: to_set(surfaces))}
  end

  defp changed(_message, socket), do: {:cont, socket}

  # Read once at mount, because a subscription only reports what happens next
  # and the tab may already have been open for an hour.
  defp paths(socket, nickname) do
    if connected?(socket), do: nickname |> Surfaces.list() |> to_set(), else: MapSet.new()
  end

  defp to_set(surfaces) do
    surfaces
    |> Enum.map(& &1.path)
    |> Enum.filter(&is_binary/1)
    |> MapSet.new()
  end
end
