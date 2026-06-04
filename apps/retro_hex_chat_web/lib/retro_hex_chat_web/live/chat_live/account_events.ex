defmodule RetroHexChatWeb.ChatLive.AccountEvents do
  @moduledoc """
  Handle Account dialog and status-bar account events.

  Attached as `attach_hook(:account_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.CommandDispatch
  alias RetroHexChatWeb.ChatLive.Helpers

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}

  def handle_event("open_account_dialog", _params, socket) do
    {:halt, open_account(socket, "register", default_auth_mode(socket))}
  end

  def handle_event("open_account_register", _params, socket) do
    {:halt, open_account(socket, "register", "register")}
  end

  def handle_event("open_account_identify", _params, socket) do
    {:halt, open_account(socket, "register", "identify")}
  end

  def handle_event("open_account_profile", _params, socket) do
    {:halt, open_account(socket, "profile", default_auth_mode(socket))}
  end

  def handle_event("open_account_presence", _params, socket) do
    {:halt, open_account(socket, "presence", default_auth_mode(socket))}
  end

  def handle_event("open_account_modes", _params, socket) do
    {:halt, open_account(socket, "modes", default_auth_mode(socket))}
  end

  def handle_event("close_account_dialog", _params, socket) do
    {:halt, assign(socket, show_account_dialog: false, account_error: nil)}
  end

  def handle_event("account_info", _params, socket) do
    {:halt, dispatch(socket, "ns", ["info"])}
  end

  def handle_event("toggle_account_away", _params, socket) do
    session = socket.assigns.session

    if session.away do
      {:halt, dispatch(socket, "away", [])}
    else
      message = socket.assigns.account_last_away_message || dgettext("chat", "Away")

      {:halt,
       socket
       |> dispatch("away", [message])
       |> assign(account_last_away_message: message)}
    end
  end

  def handle_event("account_register_submit", params, socket) do
    mode = params["mode"] || "register"
    password = params["password"] || ""
    confirm = params["confirm"] || ""

    cond do
      mode == "register" and password != confirm ->
        {:halt,
         assign(socket,
           account_auth_mode: "register",
           account_error: dgettext("chat", "Passwords do not match")
         )}

      password == "" ->
        {:halt,
         assign(socket,
           account_auth_mode: mode,
           account_error: dgettext("chat", "Password is required")
         )}

      mode == "identify" ->
        {:halt,
         socket
         |> assign(account_error: nil, account_auth_mode: "identify")
         |> dispatch("ns", ["identify", password])
         |> sync_identity()}

      true ->
        {:halt,
         socket
         |> assign(account_error: nil, account_auth_mode: "register")
         |> dispatch("ns", ["register", password])
         |> sync_identity()}
    end
  end

  def handle_event("account_change_nick_submit", %{"nickname" => nickname}, socket) do
    {:halt, dispatch(socket, "nick", [nickname])}
  end

  def handle_event("account_profile_submit", %{"bio" => bio}, socket) do
    args = if String.trim(bio) == "", do: ["clear"], else: [String.slice(bio, 0, 200)]
    {:halt, dispatch(socket, "bio", args)}
  end

  def handle_event("account_clear_bio", _params, socket) do
    {:halt, dispatch(socket, "bio", ["clear"])}
  end

  def handle_event("account_presence_submit", params, socket) do
    message =
      params
      |> Map.get("away_message", "")
      |> String.trim()
      |> case do
        "" -> dgettext("chat", "Away")
        value -> value
      end

    {:halt,
     socket
     |> dispatch("away", [message])
     |> assign(account_last_away_message: message)}
  end

  def handle_event("account_clear_away", _params, socket) do
    {:halt, dispatch(socket, "away", [])}
  end

  def handle_event("account_user_modes_submit", params, socket) do
    mode_string = if truthy?(params["wallops"]), do: "+w", else: "-w"
    {:halt, dispatch(socket, "umode", [mode_string])}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  defp open_account(socket, tab, auth_mode) do
    socket
    |> assign(
      show_account_dialog: true,
      account_dialog_tab: tab,
      account_auth_mode: auth_mode,
      account_error: nil
    )
    |> sync_identity()
  end

  defp default_auth_mode(socket) do
    if NickServ.registered?(socket.assigns.session.nickname), do: "identify", else: "register"
  end

  defp dispatch(socket, name, args) do
    CommandDispatch.dispatch_command(socket, socket.assigns.session, name, args)
  end

  defp sync_identity(socket) do
    session = socket.assigns.session
    registered = NickServ.registered?(session.nickname)
    identified = NickServ.identified?(session.nickname)
    was_identified = session.identified

    session =
      session
      |> Session.set_identified(identified)
      |> maybe_load_persisted_data(session.nickname, identified, was_identified)

    socket
    |> assign(session: session, account_registered: registered)
    |> maybe_rebuild_nick_color_fn(session, identified, was_identified)
  end

  defp maybe_load_persisted_data(session, nickname, true, false),
    do: Helpers.load_persisted_data(session, nickname)

  defp maybe_load_persisted_data(session, _nickname, _identified, _was_identified), do: session

  defp maybe_rebuild_nick_color_fn(socket, session, true, false),
    do: Helpers.rebuild_nick_color_fn(socket, session)

  defp maybe_rebuild_nick_color_fn(socket, _session, _identified, _was_identified), do: socket

  defp truthy?(true), do: true
  defp truthy?("true"), do: true
  defp truthy?(_value), do: false
end
