defmodule RetroHexChatWeb.V2.ConnectLive do
  @moduledoc """
  v2 connection dialog using new UI components.
  Users enter nickname and connect. If registered, a password step is shown.
  On success, a hidden form POSTs to `/chat/session`.
  """
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.Components.UI.Alert
  import RetroHexChatWeb.Components.UI.Fieldset
  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.MenuBarApp
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.Components.UI.AboutDialog
  import RetroHexChatWeb.Icons

  alias Phoenix.LiveView.JS
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
  def handle_event("validate", %{"nickname" => nickname}, socket) do
    error =
      case validate_nickname(nickname) do
        :ok -> nil
        {:error, msg} -> msg
      end

    {:noreply, assign(socket, nickname: nickname, nickname_error: error)}
  end

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
        {:noreply, assign(socket, nickname_error: msg)}
    end
  end

  def handle_event("validate_password", %{"password" => password}, socket) do
    {:noreply, assign(socket, password: password, password_error: nil)}
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

  def handle_event("validate_register", params, socket) do
    password = Map.get(params, "password", "")
    password_confirm = Map.get(params, "password_confirm", "")

    {:noreply,
     assign(socket, password: password, password_confirm: password_confirm, password_error: nil)}
  end

  def handle_event("register", params, socket) do
    password = Map.get(params, "password", "")
    password_confirm = Map.get(params, "password_confirm", "")
    nickname = socket.assigns.nickname

    cond do
      String.length(password) < 5 ->
        {:noreply,
         assign(socket,
           password_error: dgettext("connect", "Password must be at least 5 characters")
         )}

      password != password_confirm ->
        {:noreply, assign(socket, password_error: dgettext("connect", "Passwords do not match"))}

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
            {:noreply, assign(socket, password_error: msg)}
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

  attr :nickname, :string, required: true
  attr :nickname_error, :string, default: nil

  defp nickname_step(assigns) do
    ~H"""
    <form phx-submit="connect" phx-change="validate">
      <.retro_fieldset legend={dgettext("connect", "User Information")}>
        <.field_row stacked>
          <.label for="nickname">
            <.icon_status_user class="w-3.5 h-3.5 inline-block" /> {dgettext("connect", "Nickname")}
          </.label>
          <.input
            type="text"
            id="nickname"
            name="nickname"
            value={@nickname}
            maxlength="16"
            autocomplete="off"
            placeholder={dgettext("connect", "Enter your nickname...")}
            phx-debounce="300"
            phx-mounted={JS.focus()}
          />
        </.field_row>
        <ul class="text-xs mt-2 space-y-0.5 text-muted-foreground">
          <li>
            <.icon_checkmark class="w-3 h-3 inline-block" /> {dgettext("connect", "1-16 characters")}
          </li>
          <li>
            <.icon_checkmark class="w-3 h-3 inline-block" /> {dgettext(
              "connect",
              "Must start with a letter"
            )}
          </li>
          <li>
            <.icon_checkmark class="w-3 h-3 inline-block" /> {dgettext("connect", "No spaces allowed")}
          </li>
          <li>
            <.icon_checkmark class="w-3 h-3 inline-block" /> {dgettext("connect", "Case sensitive")}
          </li>
        </ul>
        <p :if={@nickname_error} class="text-destructive text-xs mt-2">
          <.icon_reject class="w-3 h-3 inline-block" /> {@nickname_error}
        </p>
      </.retro_fieldset>

      <div class="flex justify-end gap-2 mt-4">
        <.button
          type="submit"
          data-testid="connect-btn"
          disabled={@nickname_error != nil or @nickname == ""}
        >
          <:icon><.icon_connect /></:icon>
          {dgettext("connect", "Connect")}
        </.button>
      </div>

      <div class="mt-4 space-y-2 text-xs">
        <div class="flex gap-2 items-start p-2 bg-canvas shadow-retro-field">
          <.icon_connect class="w-3.5 h-3.5 shrink-0 mt-0.5" />
          <div>
            <strong>{dgettext("connect", "One session per nickname")}</strong>
            <p class="text-muted-foreground">
              {dgettext("connect", "Connecting from another window ends the previous session.")}
            </p>
          </div>
        </div>
        <div class="flex gap-2 items-start p-2 bg-canvas shadow-retro-field">
          <.icon_clock class="w-3.5 h-3.5 shrink-0 mt-0.5" />
          <div>
            <strong>{dgettext("connect", "Session expiry")}</strong>
            <p class="text-muted-foreground">
              {dgettext("connect", "Sessions expire after 10 failed reconnection attempts.")}
            </p>
          </div>
        </div>
        <div
          class="flex gap-2 items-start p-2 bg-canvas shadow-retro-field"
          data-testid="nick-expiry-notice"
        >
          <.icon_warning class="w-3.5 h-3.5 shrink-0 mt-0.5" />
          <div>
            <strong>{dgettext("connect", "Nickname cleanup")}</strong>
            <p class="text-muted-foreground">
              {dgettext("connect", "Nicknames unused for 7 days are automatically released.")}
            </p>
          </div>
        </div>
      </div>
    </form>
    """
  end

  attr :nickname, :string, required: true
  attr :password, :string, required: true
  attr :password_error, :string, default: nil

  defp password_step(assigns) do
    ~H"""
    <form phx-submit="authenticate" phx-change="validate_password" autocomplete="off">
      <.retro_fieldset legend={dgettext("connect", "Authentication")}>
        <.alert class="mb-3">
          <:icon><.icon_shield /></:icon>
          <.alert_description>
            {dgettext(
              "connect",
              "The nickname %{nickname} is registered. Please enter your password to continue.",
              nickname: @nickname
            )}
          </.alert_description>
        </.alert>

        <.field_row stacked>
          <.label for="password">
            <.icon_lock class="w-3.5 h-3.5 inline-block" /> {dgettext("connect", "Password")}
          </.label>
          <.input
            type="text"
            class="input-masked"
            id="password"
            name="password"
            value={@password}
            placeholder={dgettext("connect", "Enter your password...")}
            autocomplete="off"
            data-1p-ignore
            data-lpignore="true"
            data-bwignore="true"
            phx-mounted={JS.focus()}
          />
        </.field_row>
        <p :if={@password_error} class="text-destructive text-xs mt-2">
          <.icon_reject class="w-3 h-3 inline-block" /> {@password_error}
        </p>
      </.retro_fieldset>

      <div class="flex justify-end gap-2 mt-4">
        <.button type="button" variant="outline" phx-click="back" data-testid="back-btn">
          <:icon><.icon_btn_prev /></:icon>
          {dgettext("connect", "Back")}
        </.button>
        <.button type="submit" data-testid="auth-btn" disabled={@password == ""}>
          <:icon><.icon_connect /></:icon>
          {dgettext("connect", "Connect")}
        </.button>
      </div>
    </form>
    """
  end

  attr :nickname, :string, required: true
  attr :password, :string, required: true
  attr :password_confirm, :string, required: true
  attr :password_error, :string, default: nil

  defp register_step(assigns) do
    ~H"""
    <form phx-submit="register" phx-change="validate_register" autocomplete="off">
      <.retro_fieldset legend={dgettext("connect", "Registration")}>
        <.alert class="mb-3">
          <:icon><.icon_checkmark /></:icon>
          <.alert_description>
            {dgettext(
              "connect",
              "The nickname %{nickname} is available! Choose a password to register it.",
              nickname: @nickname
            )}
          </.alert_description>
        </.alert>

        <.field_row stacked class="mb-2">
          <.label for="reg-password">
            <.icon_lock class="w-3.5 h-3.5 inline-block" /> {dgettext("connect", "Password")}
          </.label>
          <.input
            type="text"
            class="input-masked"
            id="reg-password"
            name="password"
            value={@password}
            placeholder={dgettext("connect", "Choose a password (min. 5 characters)...")}
            autocomplete="off"
            data-1p-ignore
            data-lpignore="true"
            data-bwignore="true"
            phx-mounted={JS.focus()}
          />
        </.field_row>

        <.field_row stacked>
          <.label for="reg-password-confirm">
            <.icon_lock class="w-3.5 h-3.5 inline-block" /> {dgettext("connect", "Confirm password")}
          </.label>
          <.input
            type="text"
            class="input-masked"
            id="reg-password-confirm"
            name="password_confirm"
            value={@password_confirm}
            placeholder={dgettext("connect", "Repeat your password...")}
            autocomplete="off"
            data-1p-ignore
            data-lpignore="true"
            data-bwignore="true"
          />
        </.field_row>
        <p :if={@password_error} class="text-destructive text-xs mt-2">
          <.icon_reject class="w-3 h-3 inline-block" /> {@password_error}
        </p>
      </.retro_fieldset>

      <div class="flex justify-end gap-2 mt-4">
        <.button type="button" variant="outline" phx-click="back" data-testid="back-btn">
          <:icon><.icon_btn_prev /></:icon>
          {dgettext("connect", "Back")}
        </.button>
        <.button
          type="submit"
          data-testid="register-btn"
          disabled={@password == "" or @password_confirm == ""}
        >
          <:icon><.icon_connect /></:icon>
          {dgettext("connect", "Register & Connect")}
        </.button>
      </div>
    </form>
    """
  end
end
