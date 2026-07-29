defmodule RetroHexChatWeb.App.ConnectLive do
  @moduledoc """
  Connection dialog using app UI components.
  Users enter nickname and connect. If registered, a password step is shown.
  On success, a hidden form POSTs to `/chat/session`.
  """
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ConnectScreen

  alias RetroHexChat.Accounts.NicknameValidator
  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Services.NickServ

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, session, socket) do
    trusted_device_id = session["trusted_device_id"]
    remembered_nicks = TrustedDevices.remembered_nicks(trusted_device_id)

    {:ok,
     assign(socket,
       nickname: "",
       nickname_error: nil,
       password: "",
       password_confirm: "",
       password_error: nil,
       step: :nickname,
       auth_token: nil,
       trusted_device_id: trusted_device_id,
       remembered_nicks: remembered_nicks,
       manual_login: false,
       trusted_device_login: false,
       remember_device: false,
       device_label: "",
       submit_connect: false,
       page_title: dgettext("connect", "Connect - RetroHexChat")
     )}
  end

  @impl true
  def handle_params(%{"reason" => reason}, _uri, socket) do
    message = reason_to_message(reason)
    {:noreply, put_flash(socket, :error, message)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, maybe_auto_login(socket)}
  end

  @spec reason_to_message(String.t()) :: String.t()
  defp reason_to_message("expired"), do: dgettext("connect", "Session expired")
  defp reason_to_message("disconnected"), do: dgettext("connect", "Session ended")
  defp reason_to_message("banned"), do: dgettext("connect", "Server banned")
  defp reason_to_message(reason), do: reason

  @impl true
  def handle_event("connect", %{"nickname" => nickname}, socket) do
    case validate_nickname(nickname) do
      :ok ->
        route_valid_nickname(socket, nickname)

      {:error, msg} ->
        {:noreply, assign(socket, nickname: nickname, nickname_error: msg)}
    end
  end

  def handle_event("connect_remembered", %{"nickname" => nickname}, socket) do
    if TrustedDevices.nick_remembered?(socket.assigns.trusted_device_id, nickname) do
      {:noreply,
       socket
       |> assign(
         nickname: nickname,
         auth_token: nil,
         trusted_device_login: true,
         remember_device: false,
         device_label: "",
         submit_connect: true
       )
       |> push_event("submit_connect", %{})}
    else
      {:noreply, assign(socket, nickname_error: dgettext("connect", "Trusted login expired"))}
    end
  end

  def handle_event(
        "trusted_auto_login_toggle",
        %{"nickname" => nickname, "enabled" => enabled},
        socket
      ) do
    case TrustedDevices.set_auto_login(
           socket.assigns.trusted_device_id,
           nickname,
           truthy?(enabled),
           nickname
         ) do
      :ok ->
        {:noreply,
         assign(socket,
           remembered_nicks: TrustedDevices.remembered_nicks(socket.assigns.trusted_device_id)
         )}

      {:error, message} ->
        {:noreply, assign(socket, nickname_error: message)}
    end
  end

  def handle_event("manual_login", _params, socket) do
    {:noreply,
     assign(socket,
       manual_login: true,
       nickname: "",
       nickname_error: nil,
       trusted_device_login: false,
       auth_token: nil
     )}
  end

  def handle_event("trusted_choices", _params, socket) do
    {:noreply,
     assign(socket,
       manual_login: false,
       nickname: "",
       nickname_error: nil,
       trusted_device_login: false,
       auth_token: nil
     )}
  end

  def handle_event("authenticate", %{"password" => password} = params, socket) do
    nickname = socket.assigns.nickname

    case NickServ.identify(nickname, password) do
      {:ok, _msg} ->
        token =
          Phoenix.Token.sign(RetroHexChatWeb.Endpoint, "nickserv_identify", nickname)

        {:noreply,
         socket
         |> assign_auth_success(token, params)
         |> push_event("submit_connect", %{})}

      {:error, _msg} ->
        {:noreply,
         socket
         |> assign(password_error: dgettext("connect", "Incorrect password"), password: "")
         |> assign_remember_device_fields(params)}
    end
  end

  def handle_event("register", params, socket) do
    password = Map.get(params, "password", "")
    password_confirm = Map.get(params, "password_confirm", "")
    nickname = socket.assigns.nickname

    cond do
      String.length(password) < 5 ->
        {:noreply,
         socket
         |> assign(
           password: password,
           password_confirm: password_confirm,
           password_error: dgettext("connect", "Password must be at least 5 characters")
         )
         |> assign_remember_device_fields(params)}

      password != password_confirm ->
        {:noreply,
         socket
         |> assign(
           password: password,
           password_confirm: password_confirm,
           password_error: dgettext("connect", "Passwords do not match")
         )
         |> assign_remember_device_fields(params)}

      true ->
        case NickServ.register(nickname, password) do
          {:ok, _msg} ->
            token =
              Phoenix.Token.sign(RetroHexChatWeb.Endpoint, "nickserv_identify", nickname)

            {:noreply,
             socket
             |> assign_auth_success(token, params)
             |> push_event("submit_connect", %{})}

          {:error, msg} ->
            {:noreply,
             socket
             |> assign(
               password: password,
               password_confirm: password_confirm,
               password_error: msg
             )
             |> assign_remember_device_fields(params)}
        end
    end
  end

  def handle_event("back", _params, socket) do
    {:noreply,
     assign(socket,
       step: :nickname,
       password: "",
       password_confirm: "",
       password_error: nil
     )}
  end

  def handle_event("help_topics", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/chat/help")}
  end

  def handle_event("menu_action", %{"action" => "help_topics"}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/chat/help")}
  end

  # The disconnected menu bar still emits actions this screen has no feature
  # for (MOTD, cheatsheet); ignore them instead of crashing the LiveView.
  def handle_event("menu_action", _params, socket), do: {:noreply, socket}

  defp validate_nickname(nickname) do
    case NicknameValidator.validate(nickname) do
      :ok -> :ok
      {:error, message} -> {:error, translate_nickname_error(message)}
    end
  end

  defp translate_nickname_error("Nickname must be a string"),
    do: dgettext("connect", "Nickname must be a string")

  defp translate_nickname_error("Nickname cannot be empty"),
    do: dgettext("connect", "Nickname cannot be empty")

  defp translate_nickname_error("Nickname must be at most 16 characters"),
    do: dgettext("connect", "Nickname must be at most 16 characters")

  defp translate_nickname_error("Nickname must start with a letter or special character"),
    do: dgettext("connect", "Nickname must start with a letter or special character")

  defp translate_nickname_error("Nickname cannot contain spaces"),
    do: dgettext("connect", "Nickname cannot contain spaces")

  defp translate_nickname_error(message), do: message

  defp route_valid_nickname(socket, nickname) do
    cond do
      TrustedDevices.nick_remembered?(socket.assigns.trusted_device_id, nickname) ->
        {:noreply,
         socket
         |> assign(
           nickname: nickname,
           nickname_error: nil,
           auth_token: nil,
           trusted_device_login: true,
           remember_device: false,
           device_label: "",
           submit_connect: true
         )
         |> push_event("submit_connect", %{})}

      NickServ.registered?(nickname) ->
        {:noreply,
         assign(socket,
           step: :password,
           nickname: nickname,
           password: "",
           password_error: nil,
           trusted_device_login: false
         )}

      true ->
        {:noreply,
         assign(socket,
           step: :register,
           nickname: nickname,
           password: "",
           password_confirm: "",
           password_error: nil,
           trusted_device_login: false
         )}
    end
  end

  defp maybe_auto_login(%{assigns: %{manual_login: true}} = socket), do: socket

  defp maybe_auto_login(socket) do
    case TrustedDevices.auto_login_nick(socket.assigns.trusted_device_id) do
      %{nickname: nickname} when is_binary(nickname) ->
        socket =
          assign(socket,
            nickname: nickname,
            nickname_error: nil,
            auth_token: nil,
            trusted_device_login: true,
            remember_device: false,
            device_label: "",
            submit_connect: true
          )

        if connected?(socket), do: push_event(socket, "submit_connect", %{}), else: socket

      _ ->
        socket
    end
  end

  defp assign_auth_success(socket, token, params) do
    assign(socket,
      auth_token: token,
      trusted_device_login: false,
      remember_device: truthy?(params["remember_device"]),
      device_label: params["device_label"] || "",
      submit_connect: true
    )
  end

  defp assign_remember_device_fields(socket, params) do
    assign(socket,
      remember_device: truthy?(params["remember_device"]),
      device_label: params["device_label"] || ""
    )
  end

  defp truthy?(value), do: value in [true, "true", "on", "1", 1]
end
