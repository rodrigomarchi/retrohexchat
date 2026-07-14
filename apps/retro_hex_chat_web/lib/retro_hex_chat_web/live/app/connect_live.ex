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
  alias RetroHexChat.Services.NickServ

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       nickname: "",
       nickname_error: nil,
       password: "",
       password_confirm: "",
       password_error: nil,
       step: :nickname,
       auth_token: nil,
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
    {:noreply, socket}
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
        if NickServ.registered?(nickname) do
          {:noreply,
           assign(socket, step: :password, nickname: nickname, password: "", password_error: nil)}
        else
          {:noreply,
           assign(socket,
             step: :register,
             nickname: nickname,
             password: "",
             password_confirm: "",
             password_error: nil
           )}
        end

      {:error, msg} ->
        {:noreply, assign(socket, nickname: nickname, nickname_error: msg)}
    end
  end

  def handle_event("authenticate", %{"password" => password}, socket) do
    nickname = socket.assigns.nickname

    case NickServ.identify(nickname, password) do
      {:ok, _msg} ->
        token =
          Phoenix.Token.sign(RetroHexChatWeb.Endpoint, "nickserv_identify", nickname)

        {:noreply,
         socket
         |> assign(auth_token: token, submit_connect: true)
         |> push_event("submit_connect", %{})}

      {:error, _msg} ->
        {:noreply,
         assign(socket, password_error: dgettext("connect", "Incorrect password"), password: "")}
    end
  end

  def handle_event("register", params, socket) do
    password = Map.get(params, "password", "")
    password_confirm = Map.get(params, "password_confirm", "")
    nickname = socket.assigns.nickname

    cond do
      String.length(password) < 5 ->
        {:noreply,
         assign(socket,
           password: password,
           password_confirm: password_confirm,
           password_error: dgettext("connect", "Password must be at least 5 characters")
         )}

      password != password_confirm ->
        {:noreply,
         assign(socket,
           password: password,
           password_confirm: password_confirm,
           password_error: dgettext("connect", "Passwords do not match")
         )}

      true ->
        case NickServ.register(nickname, password) do
          {:ok, _msg} ->
            token =
              Phoenix.Token.sign(RetroHexChatWeb.Endpoint, "nickserv_identify", nickname)

            {:noreply,
             socket
             |> assign(auth_token: token, submit_connect: true)
             |> push_event("submit_connect", %{})}

          {:error, msg} ->
            {:noreply,
             assign(socket,
               password: password,
               password_confirm: password_confirm,
               password_error: msg
             )}
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
end
