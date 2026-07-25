defmodule RetroHexChatWeb.ChatLive.AccountEvents do
  @moduledoc """
  Handle the Account window (register/identify, drop registration, ghost
  session) and the status-bar account widget.

  `sync_identity/1` runs two NickServ lookups, so it fires only when this window
  opens — it is the one that displays the result. The sibling account windows
  (Profile, Away, User Modes) do not pay for it.

  Attached as `attach_hook(:account_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.CommandDispatch
  alias RetroHexChatWeb.ChatLive.Components.AccountDialog
  alias RetroHexChatWeb.ChatLive.Helpers
  alias RetroHexChatWeb.ChatLive.Windows

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}

  def handle_event("open_account_dialog", _params, socket), do: {:halt, open(socket)}
  def handle_event("open_account_register", _params, socket), do: {:halt, open(socket)}
  def handle_event("open_account_identify", _params, socket), do: {:halt, open(socket)}

  def handle_event("close_account_dialog", _params, socket) do
    {:halt, push_event(socket, "window_command", %{action: "close", id: "account"})}
  end

  def handle_event("account_info", _params, socket) do
    {:halt, CommandDispatch.dispatch_command(socket, socket.assigns.session, "ns", ["info"])}
  end

  def handle_event("account_register_submit", params, socket) do
    mode = auth_mode(socket)
    password = params["password"] || ""
    confirm = params["confirm"] || ""

    cond do
      mode == "register" and password != confirm ->
        {:halt, auth_error(socket, dgettext("chat", "Passwords do not match"))}

      password == "" ->
        {:halt, auth_error(socket, dgettext("chat", "Password is required"))}

      mode == "identify" ->
        {:halt, submit_nickserv(socket, "identify", [password])}

      true ->
        {:halt, submit_nickserv(socket, "register", [password])}
    end
  end

  def handle_event("account_drop_submit", params, socket) do
    password = params["password"] || ""

    if password == "" do
      {:halt, auth_error(socket, dgettext("chat", "Password is required"))}
    else
      {:halt, submit_nickserv(socket, "drop", [password])}
    end
  end

  def handle_event("account_auth_change", params, socket) do
    mode = auth_mode(socket)
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

    send_update(AccountDialog,
      id: AccountDialog.id(),
      action: {:auth, valid?, error, %{password: password, confirm: confirm}}
    )

    {:halt, socket}
  end

  def handle_event("account_ghost_submit", params, socket) do
    nickname = String.trim(params["nickname"] || "")
    password = params["password"] || ""

    cond do
      nickname == "" ->
        {:halt, ghost_error(socket, dgettext("chat", "Nickname is required"))}

      password == "" ->
        {:halt, ghost_error(socket, dgettext("chat", "Password is required"))}

      true ->
        {:halt, submit_nickserv(socket, "ghost", [nickname, password])}
    end
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc "Opens/focuses the Account window, refreshing the NickServ identity first."
  @spec open(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket) do
    socket
    |> sync_identity()
    |> Windows.open("account")
  end

  @doc """
  Refreshes `session.identified` and the `account_registered` snapshot from
  NickServ, loading the persisted data on a fresh identification.
  """
  @spec sync_identity(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def sync_identity(socket) do
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

  defp submit_nickserv(socket, subcommand, args) do
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
        |> reflect_nickserv_error(subcommand, message)

      _result ->
        socket = sync_identity(socket)
        send_update(AccountDialog, id: AccountDialog.id(), action: :auth_reset)
        socket
    end
  end

  defp reflect_nickserv_error(socket, "ghost", message), do: ghost_error(socket, message)
  defp reflect_nickserv_error(socket, _subcommand, message), do: auth_error(socket, message)

  defp auth_error(socket, message) do
    send_update(AccountDialog, id: AccountDialog.id(), action: {:auth_error, message})
    socket
  end

  defp ghost_error(socket, message) do
    send_update(AccountDialog, id: AccountDialog.id(), action: {:ghost_error, message})
    socket
  end

  # The nickname is either registered (identify) or not (register); the form
  # never offers a choice, so the mode is derived rather than taken from params.
  defp auth_mode(socket) do
    registered =
      Map.get(socket.assigns, :account_registered, false) ||
        NickServ.registered?(socket.assigns.session.nickname)

    if registered, do: "identify", else: "register"
  end

  defp maybe_load_persisted_data(session, nickname, true, false),
    do: Helpers.load_persisted_data(session, nickname)

  defp maybe_load_persisted_data(session, _nickname, _identified, _was_identified), do: session

  defp maybe_rebuild_nick_color_fn(socket, session, true, false),
    do: Helpers.rebuild_nick_color_fn(socket, session)

  defp maybe_rebuild_nick_color_fn(socket, _session, _identified, _was_identified), do: socket
end
