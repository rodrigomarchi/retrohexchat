defmodule RetroHexChatWeb.ChatLive.Components.StatusViewport do
  @moduledoc """
  The status-tab message log. Owns the `:status_messages` stream and renders one
  row per status line (MOTD, system events, errors, routed notices), so the status
  log re-renders only when a status line is appended — not on every parent re-render.

  The log is bounded: only the most recent `@status_limit` rows are kept in the DOM.

  The parent keeps the unread/visibility read-model (`status_unread`, `show_status_tab`)
  that the IRC tab badge and navigation read; it pushes each new status line here via
  `insert/2` (the sole mutation). Context (`timestamp_format`, `timezone`,
  `show_status_tab`) is supplied by the parent each render.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.ChatMessage

  alias RetroHexChatWeb.App.ChatHelpers

  @id "status-viewport"
  @status_limit 500

  @doc "Stable component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @doc "Appends a single status line. Returns the socket."
  @spec insert(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def insert(socket, msg) do
    send_update(__MODULE__, id: @id, action: {:insert, msg})
    socket
  end

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       id: @id,
       timestamp_format: :dd_mm_hh_mm,
       timezone: "Etc/UTC",
       show_status_tab: false
     )
     |> stream(:status_messages, [], limit: -@status_limit)}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:insert, msg}}, socket) do
    {:ok, stream_insert(socket, :status_messages, msg, limit: -@status_limit)}
  end

  def update(assigns, socket) do
    keys = [:timestamp_format, :timezone, :show_status_tab]

    merged =
      Enum.reduce(keys, %{}, fn key, acc ->
        Map.put(acc, key, Map.get(assigns, key, socket.assigns[key]))
      end)

    {:ok, assign(socket, Map.put(merged, :id, Map.get(assigns, :id, socket.assigns.id)))}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.chat_message_list
        fill
        hidden={!@show_status_tab}
        id="status-messages"
        phx-update="stream"
        testid="status-messages"
      >
        <div :for={{dom_id, msg} <- @streams.status_messages} id={dom_id}>
          <.chat_message
            timestamp={ChatHelpers.format_time(msg.timestamp, @timestamp_format, @timezone)}
            type={to_string(msg.type)}
          >
            {msg.content}
          </.chat_message>
        </div>
      </.chat_message_list>
    </div>
    """
  end
end
