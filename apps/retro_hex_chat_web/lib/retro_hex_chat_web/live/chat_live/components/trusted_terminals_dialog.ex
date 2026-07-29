defmodule RetroHexChatWeb.ChatLive.Components.TrustedTerminalsDialog do
  @moduledoc """
  Stateful island for the Trusted Terminals managed window.

  Owns two paginated lists — live sessions and security events — through
  `PaginatedList`. The remembered devices beside them are a capped list rather
  than a page: they are ordered by `last_seen_at`, and a keyset cursor over a
  key that moves would let a device slip between pages unseen, which on a
  security panel is worse than any truncation.
  """
  use RetroHexChatWeb, :live_component

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.TrustedTerminalsDialog

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Page
  alias RetroHexChatWeb.PaginatedList

  @id "trusted-terminals-dialog"

  @sessions_page_size 25
  @events_page_size 20

  @spec id() :: String.t()
  def id, do: @id

  # The inputs a snapshot is taken from. A refresh is only free-standing while
  # the lists are plain lists; with streams, refreshing on every parent render
  # would reset the pages a reader had already loaded, so it happens on open, on
  # a change of identity, and after a mutation — never as a side effect of the
  # parent re-rendering.
  @identity [:session, :trusted_device_id, :chat_device_session_ref]

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       id: @id,
       session: nil,
       timezone: "Etc/UTC",
       trusted_device_id: nil,
       chat_device_session_ref: nil,
       devices: [],
       loaded?: false,
       active_tab: "devices",
       status_kind: nil,
       status_message: nil
     )
     |> PaginatedList.init(:sessions,
       page_size: @sessions_page_size,
       dom_id: &"trusted-session-row-#{&1.id}"
     )
     |> PaginatedList.init(:events,
       page_size: @events_page_size,
       dom_id: &"trusted-event-row-#{&1.id}"
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    updated = assign(socket, assigns)

    if identity_changed?(socket, updated),
      do: {:ok, refresh_snapshot(updated)},
      else: {:ok, updated}
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

  def handle_event("trusted_terminals_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: trusted_tab(tab))}
  end

  def handle_event("load_more_sessions", _params, socket) do
    nickname = nickname(socket)
    session_ref = socket.assigns.chat_device_session_ref

    {:noreply,
     PaginatedList.load(
       socket,
       :sessions,
       &TrustedDevices.list_sessions_for_nick(nickname, session_ref, &1)
     )}
  end

  def handle_event("load_more_events", _params, socket) do
    nickname = nickname(socket)

    {:noreply,
     PaginatedList.load(socket, :events, &TrustedDevices.list_events_for_nick(nickname, &1))}
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

  def handle_event(
        "trusted_terminals_auto_login_toggle",
        %{"device_id" => id, "enabled" => enabled},
        socket
      ) do
    with {:ok, device_id} <- parse_id(id),
         {:ok, enabled?} <- parse_bool(enabled),
         :ok <-
           TrustedDevices.set_auto_login(device_id, nickname(socket), enabled?, nickname(socket)) do
      message =
        if enabled?,
          do: dgettext("chat", "Auto-login enabled."),
          else: dgettext("chat", "Auto-login disabled.")

      {:noreply,
       socket
       |> put_status(:ok, message)
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
        sessions={@streams.sessions}
        sessions_state={@paginated.sessions}
        events={@streams.events}
        events_state={@paginated.events}
        timezone={@timezone}
        active_tab={@active_tab}
        status_kind={@status_kind}
        status_message={@status_message}
        on_tab="trusted_terminals_tab"
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
        socket.assigns.chat_device_session_ref,
        sessions_limit: @sessions_page_size,
        events_limit: @events_page_size
      )

    socket
    |> assign(devices: snapshot.devices, loaded?: true)
    |> PaginatedList.reset(:sessions, snapshot.sessions)
    |> PaginatedList.reset(:events, snapshot.events)
  end

  defp refresh_snapshot(socket) do
    socket
    |> assign(devices: [], loaded?: true)
    |> PaginatedList.reset(:sessions, Page.empty())
    |> PaginatedList.reset(:events, Page.empty())
  end

  # A snapshot is worth retaking when the identity it was taken for changed, or
  # when there is no snapshot yet.
  @spec identity_changed?(Phoenix.LiveView.Socket.t(), Phoenix.LiveView.Socket.t()) :: boolean()
  defp identity_changed?(%{assigns: %{loaded?: false}}, _updated), do: true

  defp identity_changed?(%{assigns: before}, %{assigns: now}) do
    Enum.any?(@identity, &(Map.get(before, &1) != Map.get(now, &1)))
  end

  defp put_status(socket, kind, message) do
    assign(socket, status_kind: kind, status_message: message)
  end

  defp trusted_tab(tab) when tab in ["devices", "sessions", "events"], do: tab
  defp trusted_tab(_tab), do: "devices"

  defp nickname(socket), do: socket.assigns.session.nickname

  defp parse_id(id) when is_integer(id), do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed, ""} -> {:ok, parsed}
      _ -> {:error, :invalid_id}
    end
  end

  defp parse_id(_id), do: {:error, :invalid_id}

  defp parse_bool(value) when value in [true, "true"], do: {:ok, true}
  defp parse_bool(value) when value in [false, "false"], do: {:ok, false}
  defp parse_bool(_value), do: {:error, :invalid_bool}
end
