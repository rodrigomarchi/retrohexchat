defmodule RetroHexChatWeb.ChatLive.Components.TrustedTerminalsDialog do
  @moduledoc """
  Stateful island for the Trusted Terminals managed window.
  """
  use RetroHexChatWeb, :live_component

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.TrustedTerminalsDialog

  alias RetroHexChat.Accounts.TrustedDevices

  @id "trusted-terminals-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       session: nil,
       timezone: "Etc/UTC",
       trusted_device_id: nil,
       chat_device_session_ref: nil,
       devices: [],
       sessions: [],
       events: [],
       status_kind: nil,
       status_message: nil
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> refresh_snapshot()}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("trusted_terminals_refresh", _params, socket) do
    {:noreply,
     socket
     |> put_status(:ok, dgettext("chat", "Trusted terminals refreshed."))
     |> refresh_snapshot()}
  end

  def handle_event("trusted_terminals_rename_device", params, socket) do
    with {:ok, device_id} <- parse_id(params["device_id"]),
         :ok <-
           TrustedDevices.rename_device_for_nick(
             nickname(socket),
             device_id,
             params["label"] || "",
             nickname(socket)
           ) do
      {:noreply,
       socket
       |> put_status(:ok, dgettext("chat", "Trusted terminal renamed."))
       |> refresh_snapshot()}
    else
      {:error, message} when is_binary(message) ->
        {:noreply, put_status(socket, :error, message)}

      {:error, _reason} ->
        {:noreply, put_status(socket, :error, dgettext("chat", "Invalid terminal id."))}
    end
  end

  def handle_event("trusted_terminals_revoke_device", %{"id" => id}, socket) do
    with {:ok, device_id} <- parse_id(id),
         :ok <-
           TrustedDevices.revoke_device_for_nick(nickname(socket), device_id, nickname(socket)) do
      {:noreply,
       socket
       |> put_status(:ok, dgettext("chat", "Trusted terminal revoked."))
       |> refresh_snapshot()}
    else
      {:error, message} when is_binary(message) ->
        {:noreply, put_status(socket, :error, message)}

      {:error, _reason} ->
        {:noreply, put_status(socket, :error, dgettext("chat", "Invalid terminal id."))}
    end
  end

  def handle_event("trusted_terminals_forget_current", _params, socket) do
    case socket.assigns.trusted_device_id do
      id when is_integer(id) ->
        TrustedDevices.sign_out_device_for_nick(
          nickname(socket),
          id,
          nickname(socket),
          socket.assigns.chat_device_session_ref
        )

        send(self(), {:trusted_terminals_disconnect_current, "trusted-device-forgotten"})
        {:noreply, socket}

      _ ->
        {:noreply,
         put_status(socket, :error, dgettext("chat", "This terminal is not remembered."))}
    end
  end

  def handle_event("trusted_terminals_revoke_all", _params, socket) do
    count =
      TrustedDevices.sign_out_all_devices_for_nick(
        nickname(socket),
        nickname(socket),
        socket.assigns.chat_device_session_ref
      )

    if is_integer(socket.assigns.trusted_device_id) do
      send(self(), {:trusted_terminals_disconnect_current, "trusted-device-forgotten"})
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> put_status(:ok, dgettext("chat", "%{count} trusted sessions ended.", count: count))
       |> refresh_snapshot()}
    end
  end

  def handle_event("trusted_terminals_kill_session", %{"id" => id}, socket) do
    with {:ok, session_id} <- parse_id(id),
         :ok <- TrustedDevices.kill_session(nickname(socket), session_id, nickname(socket)) do
      {:noreply,
       socket
       |> put_status(:ok, dgettext("chat", "Session ended."))
       |> refresh_snapshot()}
    else
      {:error, message} when is_binary(message) ->
        {:noreply, put_status(socket, :error, message)}

      {:error, _reason} ->
        {:noreply, put_status(socket, :error, dgettext("chat", "Invalid session id."))}
    end
  end

  def handle_event("trusted_terminals_kill_other_sessions", _params, socket) do
    count =
      TrustedDevices.kill_all_sessions(
        nickname(socket),
        nickname(socket),
        socket.assigns.chat_device_session_ref
      )

    {:noreply,
     socket
     |> put_status(:ok, dgettext("chat", "%{count} sessions ended.", count: count))
     |> refresh_snapshot()}
  end

  def handle_event("trusted_terminals_close", _params, socket) do
    send(self(), {:close_window, "trusted-terminals"})
    {:noreply, socket}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.trusted_terminals_panel
        id={@id}
        target={@myself}
        nickname={if @session, do: @session.nickname, else: ""}
        identified={@session && @session.identified}
        current_device_id={@trusted_device_id}
        current_session_ref={@chat_device_session_ref}
        devices={@devices}
        sessions={@sessions}
        events={@events}
        timezone={@timezone}
        status_kind={@status_kind}
        status_message={@status_message}
        on_close="trusted_terminals_close"
      />
    </div>
    """
  end

  defp refresh_snapshot(%{assigns: %{session: %{identified: true}}} = socket) do
    snapshot =
      TrustedDevices.snapshot_for_nick(
        nickname(socket),
        socket.assigns.trusted_device_id,
        socket.assigns.chat_device_session_ref
      )

    assign(socket, snapshot)
  end

  defp refresh_snapshot(socket), do: assign(socket, devices: [], sessions: [], events: [])

  defp put_status(socket, kind, message) do
    assign(socket, status_kind: kind, status_message: message)
  end

  defp nickname(socket), do: socket.assigns.session.nickname

  defp parse_id(id) when is_integer(id), do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed, ""} -> {:ok, parsed}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_id(_id), do: {:error, :invalid_id}
end
