defmodule RetroHexChatWeb.ChatLive.AccountEvents do
  @moduledoc """
  Handle Account dialog and status-bar account events.

  Attached as `attach_hook(:account_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.{NicknameValidator, Session}
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.CommandDispatch
  alias RetroHexChatWeb.ChatLive.Helpers

  @max_bio_graphemes 200

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
    {:halt,
     socket
     |> open_account("profile", default_auth_mode(socket))
     |> dispatch("bio", [])}
  end

  def handle_event("open_account_presence", _params, socket) do
    {:halt, open_account(socket, "presence", default_auth_mode(socket))}
  end

  def handle_event("open_account_modes", _params, socket) do
    {:halt, open_account(socket, "modes", default_auth_mode(socket))}
  end

  def handle_event("close_account_dialog", _params, socket) do
    {:halt,
     assign(socket,
       show_account_dialog: false,
       account_error: nil,
       account_nick_error: nil,
       account_bio_warning: nil,
       account_ghost_error: nil
     )}
  end

  def handle_event("account_info", _params, socket) do
    {:halt, dispatch(socket, "ns", ["info"])}
  end

  def handle_event("toggle_account_away", _params, socket) do
    session = socket.assigns.session

    if session.away do
      {:halt,
       socket
       |> remember_away_message()
       |> dispatch("away", [])}
    else
      message = socket.assigns.account_last_away_message || dgettext("chat", "Away")

      {:halt,
       socket
       |> dispatch("away", [message])
       |> assign(account_last_away_message: message)}
    end
  end

  def handle_event("account_register_submit", params, socket) do
    mode = normalize_auth_mode(socket, params["mode"] || "register")
    password = params["password"] || ""
    confirm = params["confirm"] || ""

    cond do
      mode == "register" and password != confirm ->
        {:halt,
         assign(socket,
           account_auth_mode: "register",
           account_error: dgettext("chat", "Passwords do not match"),
           account_auth_valid: false
         )}

      password == "" ->
        {:halt,
         assign(socket,
           account_auth_mode: mode,
           account_error: dgettext("chat", "Password is required"),
           account_auth_valid: false
         )}

      mode == "identify" ->
        {:halt, submit_nickserv(socket, "identify", [password], "identify")}

      true ->
        {:halt, submit_nickserv(socket, "register", [password], "register")}
    end
  end

  def handle_event("account_drop_submit", params, socket) do
    password = params["password"] || ""

    if password == "" do
      {:halt,
       assign(socket,
         account_auth_mode: default_auth_mode(socket),
         account_error: dgettext("chat", "Password is required"),
         account_auth_valid: false
       )}
    else
      {:halt, submit_nickserv(socket, "drop", [password], default_auth_mode(socket))}
    end
  end

  def handle_event("account_auth_change", params, socket) do
    mode = normalize_auth_mode(socket, params["mode"] || "register")
    password = params["password"] || ""
    confirm = params["confirm"] || ""

    {valid?, error} =
      cond do
        password == "" ->
          {false, nil}

        mode == "register" and password != confirm ->
          {false, dgettext("chat", "Passwords do not match")}

        true ->
          {true, nil}
      end

    {:halt,
     assign(socket,
       account_auth_mode: mode,
       account_error: error,
       account_auth_valid: valid?
     )}
  end

  def handle_event("account_ghost_submit", params, socket) do
    nickname = String.trim(params["nickname"] || "")
    password = params["password"] || ""

    cond do
      nickname == "" ->
        {:halt, assign(socket, account_ghost_error: dgettext("chat", "Nickname is required"))}

      password == "" ->
        {:halt, assign(socket, account_ghost_error: dgettext("chat", "Password is required"))}

      true ->
        {:halt, submit_nickserv(socket, "ghost", [nickname, password], default_auth_mode(socket))}
    end
  end

  def handle_event("account_change_nick_submit", %{"nickname" => nickname}, socket) do
    nickname = String.trim(nickname)

    case validate_nickname_change(socket.assigns.session.nickname, nickname) do
      :ok ->
        {socket, result} =
          CommandDispatch.dispatch_command_with_result(
            socket,
            socket.assigns.session,
            "nick",
            [nickname]
          )

        case result do
          {:error, message} -> {:halt, assign(socket, account_nick_error: message)}
          _result -> {:halt, assign(socket, account_nick_error: nil)}
        end

      {:error, message} ->
        {:halt, assign(socket, account_nick_error: message)}
    end
  end

  def handle_event("account_profile_change", %{"bio" => bio}, socket) do
    {draft, warning} = normalize_bio_draft(bio)

    {:halt,
     assign(socket,
       account_bio_draft: draft,
       account_bio_warning: warning
     )}
  end

  def handle_event("account_profile_submit", %{"bio" => bio}, socket) do
    {bio, warning} = normalize_bio_draft(bio)
    args = if String.trim(bio) == "", do: ["clear"], else: [bio]

    {:halt,
     socket
     |> assign(account_bio_draft: bio, account_bio_warning: warning)
     |> dispatch("bio", args)}
  end

  def handle_event("account_clear_bio", _params, socket) do
    {:halt,
     socket
     |> assign(account_bio_draft: "", account_bio_warning: nil)
     |> dispatch("bio", ["clear"])}
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

    if truthy?(Map.get(params, "away", "true")) do
      {:halt,
       socket
       |> dispatch("away", [message])
       |> assign(account_last_away_message: message)}
    else
      {:halt,
       socket
       |> remember_away_message(message)
       |> dispatch("away", [])}
    end
  end

  def handle_event("account_clear_away", _params, socket) do
    {:halt,
     socket
     |> remember_away_message()
     |> dispatch("away", [])}
  end

  def handle_event("account_user_modes_submit", params, socket) do
    mode_string = if truthy?(params["wallops"]), do: "+w", else: "-w"
    {:halt, dispatch(socket, "umode", [mode_string])}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  defp open_account(socket, tab, auth_mode) do
    socket =
      socket
      |> assign(
        show_account_dialog: true,
        account_dialog_tab: tab,
        account_auth_mode: auth_mode,
        account_error: nil,
        account_auth_valid: false,
        account_nick_error: nil,
        account_bio_warning: nil,
        account_ghost_error: nil
      )
      |> sync_identity()

    assign(socket,
      account_auth_mode: normalize_auth_mode(socket, auth_mode),
      account_bio_draft: Session.get_bio(socket.assigns.session) || ""
    )
  end

  defp submit_nickserv(socket, subcommand, args, auth_mode) do
    {socket, result} =
      CommandDispatch.dispatch_command_with_result(
        socket,
        socket.assigns.session,
        "ns",
        [subcommand | args]
      )

    case result do
      {:error, message} ->
        socket
        |> sync_identity()
        |> assign_nickserv_error(subcommand, message, auth_mode)

      _result ->
        socket =
          socket
          |> assign(account_error: nil, account_ghost_error: nil, account_auth_valid: false)
          |> sync_identity()

        assign(socket, account_auth_mode: default_auth_mode(socket))
    end
  end

  defp assign_nickserv_error(socket, "ghost", message, _auth_mode) do
    assign(socket, account_ghost_error: message)
  end

  defp assign_nickserv_error(socket, _subcommand, message, auth_mode) do
    assign_normalized_auth_error(socket, message, auth_mode)
  end

  defp normalize_auth_mode(socket, requested_mode) do
    registered =
      Map.get(socket.assigns, :account_registered, false) ||
        NickServ.registered?(socket.assigns.session.nickname)

    cond do
      registered -> "identify"
      requested_mode == "register" -> "register"
      true -> "register"
    end
  end

  defp assign_normalized_auth_error(socket, message, auth_mode) do
    assign(socket,
      account_error: message,
      account_auth_mode: normalize_auth_mode(socket, auth_mode),
      account_auth_valid: false
    )
  end

  defp validate_nickname_change(current_nickname, new_nickname) do
    if new_nickname == current_nickname do
      {:error, dgettext("chat", "You are already using that nickname")}
    else
      NicknameValidator.validate(new_nickname)
    end
  end

  defp normalize_bio_draft(bio) do
    bio = bio || ""
    draft = String.slice(bio, 0, @max_bio_graphemes)

    warning =
      if String.length(bio) > @max_bio_graphemes do
        dgettext("chat", "Bio is limited to 200 characters; extra text was not kept.")
      end

    {draft, warning}
  end

  defp remember_away_message(socket, fallback \\ nil) do
    message = socket.assigns.session.away_message || fallback

    case message do
      nil -> socket
      "" -> socket
      value -> assign(socket, account_last_away_message: value)
    end
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
