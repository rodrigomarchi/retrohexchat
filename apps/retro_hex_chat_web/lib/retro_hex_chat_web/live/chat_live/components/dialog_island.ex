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

  @doc """
  Declares a dialog island's id and the `id/0` every island answers the same
  way; given `initial:`, also its initial assigns and `mount/1`. Both stay
  readable in the island as `@id` and `@initial`. An island with a mount of
  its own passes `id:` alone. Given `load:` (a function of the socket), the
  island's `update/2` takes what the parent sends and loads once with it
  (`load_once/3`).

      use RetroHexChatWeb.ChatLive.Components.DialogIsland,
        id: "admin-motd-dialog",
        initial: %{content: nil, result: nil, loaded?: false}
  """
  defmacro __using__(opts) do
    id = Keyword.fetch!(opts, :id)

    identity =
      quote do
        @id unquote(id)

        @doc "The id the desktop renders this island under and addresses `send_update/2` to."
        @spec id() :: String.t()
        def id, do: @id
      end

    case Keyword.fetch(opts, :initial) do
      {:ok, initial} ->
        quote do
          unquote(identity)
          @initial unquote(initial)

          @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
          def mount(socket),
            do: unquote(__MODULE__).mount(socket, @id, @initial)
        end

      :error ->
        identity
    end
    |> with_loader(Keyword.get(opts, :load))
  end

  defp with_loader(code, nil), do: code

  defp with_loader(code, load) do
    quote do
      unquote(code)

      @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
      def update(assigns, socket),
        do: unquote(__MODULE__).load_once(socket, assigns, unquote(load))
    end
  end

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

  @doc """
  The socket with only `keys` taken from what the parent sent: a dialog whose
  parent re-renders with a partial set keeps the rest as it was.
  """
  @spec take(socket(), map(), [atom()]) :: socket()
  def take(socket, assigns, keys), do: assign(socket, Map.take(assigns, keys))

  @doc """
  `keys` and `:id` as the component should hold them after this update: what
  the parent sent, else what the socket already had (nil before the first
  time). Unlike `take/3`, every key is present afterwards, so a template can
  read any of them from the first render.
  """
  @spec known(socket(), map(), [atom()]) :: map()
  def known(socket, assigns, keys) do
    Map.new([:id | keys], &{&1, Map.get(assigns, &1, socket.assigns[&1])})
  end

  @typedoc """
  Where a dialog's words land in the chat around it: the status bar
  (`:system`, `:error`) or the conversation, as a line (`:system_event`,
  `:error_event`).
  """
  @type said :: :system | :error | :system_event | :error_event

  @doc """
  Says `message` in the chat around the dialog. The chat owns its status bar
  and its conversation, so a dialog sends rather than assigns; the desktop
  turns `{:dialog_said, kind, message}` into the line or the status.
  """
  @spec bubble(socket(), said(), String.t()) :: socket()
  def bubble(socket, kind, message) when kind in [:system, :error, :system_event, :error_event] do
    send(self(), {:dialog_said, kind, message})
    socket
  end

  @doc "Says `message` in the chat as an error, the way every dialog reports a failure."
  @spec bubble_error(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def bubble_error(socket, message), do: bubble(socket, :error_event, message)

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
