defmodule RetroHexChatWeb.App.LobbyLive.Components.FileIsland do
  @moduledoc """
  File-transfer island — owner of `file_transfer`/`file_transfer_ready` and the
  body of the "Files" window.

  The island is always mounted so its `FileTransferHook` (and the `filetransfer`
  data channel) stays alive for the whole connection — closing the Files window
  only hides it, it never tears down an in-flight transfer. There is no PubSub
  here: transfer control rides the data channel. The hook pushes its `ft_*`
  events to the root LiveView, which forwards them verbatim via
  `send_update(__MODULE__, action: {:ft_event, name, params})`; the island owns
  the resulting state and pushes the hook's control events (`ft_config`,
  `ft_accept`/`ft_reject`, `ft_cancel`, `ft_retry`) and its own `window_command`
  back out (C3).

  It mirrors a summary (status, sender, percent, speed, file name) to the host on
  every change so the taskbar badge and the Statistics-window connection strip can
  read it without owning the transfer (C2), and bubbles the completion notice to
  the host (`{:p2p_feature_notice, :file, text}`) for its chat sink (C1).

  Host-agnostic: the standalone lobby and the in-chat P2P session mount the
  same island — `window_id` names the desktop window it drives ("file" in the
  lobby, "p2p-files" in the chat).
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.Lobby.FilePanel

  require Logger

  @id "lobby-file"
  @default_blocked_extensions ~w(.exe .bat .cmd .com .msi .scr .pif .vbs .vbe .js .jse .wsf .wsh .ps1 .reg)

  @doc "Stable DOM/component id used by the host for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       file_transfer: nil,
       file_transfer_ready: false,
       connected: false,
       nickname: nil,
       peer_nick: nil,
       token: nil,
       window_id: "file",
       max_file_size_mb: max_file_size_mb(),
       blocked_file_extensions: blocked_file_extensions()
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:ft_event, name, params}} = assigns, socket) do
    {:ok, socket |> assign_context(assigns) |> handle_ft(name, params)}
  end

  def update(assigns, socket), do: {:ok, assign_context(socket, assigns)}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={@id} class="h-full">
      <.file_panel
        connected={@connected}
        file_transfer={@file_transfer}
        nickname={@nickname}
        max_file_size_mb={@max_file_size_mb}
        blocked_file_extensions={@blocked_file_extensions}
      />
    </div>
    """
  end

  @spec assign_context(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp assign_context(socket, assigns) do
    assign(socket,
      connected: Map.get(assigns, :connected, socket.assigns.connected),
      nickname: Map.get(assigns, :nickname, socket.assigns.nickname),
      peer_nick: Map.get(assigns, :peer_nick, socket.assigns.peer_nick),
      token: Map.get(assigns, :token, socket.assigns.token),
      window_id: Map.get(assigns, :window_id, socket.assigns.window_id)
    )
  end

  @spec handle_ft(Phoenix.LiveView.Socket.t(), String.t(), map()) ::
          Phoenix.LiveView.Socket.t()
  defp handle_ft(socket, "file_transfer_ready", _params) do
    socket
    |> assign(file_transfer_ready: true)
    |> ensure_file_transfer()
    |> maybe_push_ft_config()
    |> summarize()
  end

  defp handle_ft(socket, "ft_offer_sent", params) do
    socket
    |> assign(file_transfer: ft_meta(params, "offering", socket.assigns.nickname))
    |> summarize()
  end

  defp handle_ft(socket, "ft_offer_received", params) do
    socket
    |> assign(file_transfer: ft_meta(params, "offer_received", socket.assigns.peer_nick))
    |> push_event("window_command", %{action: "open", id: socket.assigns.window_id})
    |> summarize()
  end

  defp handle_ft(socket, "ft_respond", %{"accepted" => "true"}) do
    push_event(socket, "ft_accept", %{})
  end

  defp handle_ft(socket, "ft_respond", _params) do
    push_event(socket, "ft_reject", %{})
  end

  defp handle_ft(socket, "ft_accepted", _params) do
    socket
    |> merge_ft(%{status: "transferring", percent: 0})
    |> summarize()
  end

  defp handle_ft(socket, "ft_progress", params) do
    socket
    |> merge_ft(%{
      status: "transferring",
      percent: params["percent"],
      speed: params["speed"],
      eta: params["eta"]
    })
    |> summarize()
  end

  # A finished transfer returns to "ready" — the lobby connection stays alive.
  defp handle_ft(socket, "ft_completed", params) do
    Logger.info("Lobby file completed: #{params["file_name"]}, token=#{socket.assigns.token}")

    send(
      self(),
      {:p2p_feature_notice, :file,
       dgettext("lobby", "File transfer completed: %{name}", name: params["file_name"])}
    )

    socket
    |> assign(file_transfer: %{status: "ready"})
    |> maybe_push_ft_config()
    |> summarize()
  end

  defp handle_ft(socket, "ft_failed", params) do
    socket
    |> merge_ft(%{status: "failed", reason: params["reason"]})
    |> summarize()
  end

  defp handle_ft(socket, "ft_cancelled", _params) do
    socket
    |> assign(file_transfer: %{status: "ready"})
    |> maybe_push_ft_config()
    |> push_event("window_command", %{action: "close", id: socket.assigns.window_id})
    |> summarize()
  end

  defp handle_ft(socket, "ft_reset", _params) do
    socket
    |> assign(file_transfer: %{status: "ready"})
    |> maybe_push_ft_config()
    |> summarize()
  end

  defp handle_ft(socket, "ft_validation_error", params) do
    socket
    |> assign(file_transfer: %{status: "validation_error", validation_error: params["error"]})
    |> summarize()
  end

  defp handle_ft(socket, "ft_accept_offer", _params) do
    push_event(socket, "ft_accept", %{})
  end

  # The X on the Files window cancels an in-flight transfer (the hook tears it down)
  # and closes the window in every state, including an idle picker.
  defp handle_ft(socket, "ft_cancel", _params) do
    socket
    |> push_event("ft_cancel", %{nickname: socket.assigns.nickname})
    |> push_event("window_command", %{action: "close", id: socket.assigns.window_id})
  end

  defp handle_ft(socket, "ft_retry", _params) do
    push_event(socket, "ft_retry", %{})
  end

  defp handle_ft(socket, "ft_paused", _params) do
    socket |> merge_ft(%{status: "paused"}) |> summarize()
  end

  defp handle_ft(socket, "ft_resumed", _params) do
    socket |> merge_ft(%{status: "transferring"}) |> summarize()
  end

  defp handle_ft(socket, _name, _params), do: socket

  @spec ensure_file_transfer(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp ensure_file_transfer(%{assigns: %{file_transfer: nil}} = socket) do
    assign(socket, file_transfer: %{status: "ready"})
  end

  defp ensure_file_transfer(socket), do: socket

  @spec merge_ft(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp merge_ft(socket, patch) do
    assign(socket, file_transfer: Map.merge(socket.assigns.file_transfer || %{}, patch))
  end

  @spec maybe_push_ft_config(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp maybe_push_ft_config(%{assigns: %{file_transfer_ready: true}} = socket) do
    push_event(socket, "ft_config", %{
      max_size_mb: socket.assigns.max_file_size_mb,
      blocked_extensions: socket.assigns.blocked_file_extensions
    })
  end

  defp maybe_push_ft_config(socket), do: socket

  @spec ft_meta(map(), String.t(), String.t()) :: map()
  defp ft_meta(params, status, sender_nick) do
    %{
      status: status,
      file_name: params["file_name"],
      formatted_size: params["formatted_size"],
      sender_nick: sender_nick
    }
  end

  # The host owns the cross-cutting read-model (taskbar badge + Statistics strip);
  # mirror just the fields those readers need.
  @spec summarize(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp summarize(socket) do
    summary =
      case socket.assigns.file_transfer do
        nil -> nil
        ft -> Map.take(ft, [:status, :sender_nick, :percent, :speed, :file_name])
      end

    send(self(), {:feature_summary, :file, summary})
    socket
  end

  @spec max_file_size_mb() :: integer()
  defp max_file_size_mb do
    Application.get_env(:retro_hex_chat, :file_transfer_max_size_mb, 500)
  end

  @spec blocked_file_extensions() :: [String.t()]
  defp blocked_file_extensions do
    Application.get_env(
      :retro_hex_chat,
      :file_transfer_blocked_extensions,
      @default_blocked_extensions
    )
  end
end
