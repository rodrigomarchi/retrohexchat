defmodule RetroHexChatWeb.App.ConnectLive do
  @moduledoc """
  Pre-auth connect desktop.

  The whole NickServ flow lives in the `RetroHexChatWeb.ConnectForm` island; this
  LiveView is the host that owns the desktop chrome, the disconnect reason
  carried in the URL and the takeover card derived from it.
  """
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ConnectScreen

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChatWeb.ConnectForm

  @disconnect_context_ttl_seconds 600

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, session, socket) do
    {:ok,
     assign(socket,
       step: :nickname,
       trusted_device_id: session["trusted_device_id"],
       last_disconnect_context: last_disconnect_context(session),
       takeover_session: nil,
       auto_login: false,
       page_title: dgettext("connect", "Connect - RetroHexChat")
     )}
  end

  @impl true
  def handle_params(%{"reason" => reason}, _uri, socket) do
    message = reason_to_message(reason)

    {:noreply,
     socket
     |> assign(
       takeover_session: takeover_session(socket.assigns.last_disconnect_context),
       auto_login: false
     )
     |> put_flash(:error, message)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, takeover_session: nil, auto_login: true)}
  end

  @spec reason_to_message(String.t()) :: String.t()
  defp reason_to_message("expired"), do: dgettext("connect", "Session expired")
  defp reason_to_message("disconnected"), do: dgettext("connect", "Session ended")
  defp reason_to_message("banned"), do: dgettext("connect", "Server banned")
  defp reason_to_message(reason), do: reason

  @impl true
  def handle_event("help_topics", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/chat/help")}
  end

  def handle_event("menu_action", %{"action" => "help_topics"}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/chat/help")}
  end

  # MOTD and the cheatsheet render disabled while disconnected, so nothing here
  # should emit them; a stray action still gets ignored rather than crashing the
  # LiveView.
  def handle_event("menu_action", _params, socket), do: {:noreply, socket}

  # The status bar sits in the header, outside the island's window, so the island
  # mirrors its step up rather than the host reaching into it.
  @impl true
  def handle_info({:connect_form_step, step}, socket) do
    {:noreply, assign(socket, step: step)}
  end

  defp last_disconnect_context(%{"last_disconnect_context" => context}) when is_map(context) do
    context
  end

  defp last_disconnect_context(_session), do: nil

  defp takeover_session(nil), do: nil

  defp takeover_session(context) when is_map(context) do
    session_ref = context_value(context, :session_ref)
    nickname = context_value(context, :nickname)
    recorded_at = context_value(context, :recorded_at)

    if recent_disconnect_context?(recorded_at) do
      TrustedDevices.takeover_session_for_disconnect(session_ref, nickname)
    end
  end

  defp context_value(context, key) do
    Map.get(context, Atom.to_string(key)) || Map.get(context, key)
  end

  defp recent_disconnect_context?(recorded_at) when is_binary(recorded_at) do
    with {:ok, recorded_at, _offset} <- DateTime.from_iso8601(recorded_at),
         :gt <-
           DateTime.compare(
             DateTime.add(recorded_at, @disconnect_context_ttl_seconds, :second),
             DateTime.utc_now()
           ) do
      true
    else
      _ -> false
    end
  end

  defp recent_disconnect_context?(_recorded_at), do: false
end
