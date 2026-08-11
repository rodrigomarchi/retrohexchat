defmodule RetroHexChatWeb.ChatLive.Components.DialogIsland do
  @moduledoc """
  The lifecycle every dialog island on the desktop shares.

  A dialog is a `Phoenix.LiveComponent` that owns its own state so the chat view
  around it does not re-render whenever that state changes. Each one therefore
  starts the same way — knowing its own id, holding whatever it declares as its
  initial assigns, and holding no session until the parent sends one — and the
  ones that read from the server load once, on the first update rather than on
  every one.

  Both of those are rules about how a dialog behaves rather than about what any
  particular dialog shows, and a dialog that got either wrong would be wrong in
  a way its own tests are unlikely to describe: an island that reloads on every
  parent render still looks correct.

  What each dialog keeps is what it actually holds and what it actually loads.
  """

  import Phoenix.Component, only: [assign: 2, assign: 3]

  @type socket :: Phoenix.LiveView.Socket.t()

  @doc """
  A dialog as it first exists: its id, its declared initial assigns, no session.

  The session arrives from the parent through `update/2`, and starting at `nil`
  is what lets a dialog render its empty state rather than crash on a key that
  has not been sent yet.
  """
  @spec mount(socket(), String.t(), map()) :: {:ok, socket()}
  def mount(socket, id, initial) do
    {:ok, socket |> assign(:id, id) |> assign(initial) |> assign(session: nil)}
  end

  @doc "A dialog that only takes what the parent sends it."
  @spec update(socket(), map()) :: {:ok, socket()}
  def update(socket, assigns), do: {:ok, assign(socket, assigns)}

  @doc """
  A dialog that reads from the server, doing so on the first update only.

  The parent sends an update whenever anything it owns changes, which for a
  dialog reading an administrative snapshot would mean refetching it on
  unrelated activity. `loaded?` is the dialog's own record that it has already
  read; refreshing after that is something the reader asks for.
  """
  @spec load_once(socket(), map(), (socket() -> socket())) :: {:ok, socket()}
  def load_once(socket, assigns, load) when is_function(load, 1) do
    socket = assign(socket, assigns)

    if socket.assigns.loaded? do
      {:ok, socket}
    else
      {:ok, socket |> assign(loaded?: true) |> load.()}
    end
  end
end
