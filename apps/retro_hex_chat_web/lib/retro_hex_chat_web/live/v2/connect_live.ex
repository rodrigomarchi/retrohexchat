defmodule RetroHexChatWeb.V2.ConnectLive do
  @moduledoc """
  v2 connection dialog using new UI components.
  Users enter nickname and connect. If registered, a password step is shown.
  On success, a hidden form POSTs to `/v2/chat/session`.
  """
  use Phoenix.LiveView

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
       page_title: "Connect - RetroHexChat"
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
  defp reason_to_message("expired"), do: "Session expired"
  defp reason_to_message("disconnected"), do: "Session ended"
  defp reason_to_message(reason), do: reason

  @impl true
  def handle_event("validate", %{"nickname" => nickname}, socket) do
    error =
      case NicknameValidator.validate(nickname) do
        :ok -> nil
        {:error, msg} -> msg
      end

    {:noreply, assign(socket, nickname: nickname, nickname_error: error)}
  end

  def handle_event("connect", %{"nickname" => nickname}, socket) do
    case NicknameValidator.validate(nickname) do
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
        {:noreply, assign(socket, password_error: "Incorrect password", password: "")}
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
        {:noreply, assign(socket, password_error: "Password must be at least 5 characters")}

      password != password_confirm ->
        {:noreply, assign(socket, password_error: "Passwords do not match")}

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

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div
      class="flex items-center justify-center min-h-screen p-4"
      id="connect-root"
      phx-hook="ConnectFormHook"
    >
      <.window class="w-full max-w-md">
        <.window_title_bar title="Connect to RetroHexChat" controls={[:close]}>
          <:icon><.icon_connect class="w-4 h-4" /></:icon>
        </.window_title_bar>
        <.window_body class="p-4">
          <.alert :if={@flash["error"]} variant="destructive" class="mb-4" data-testid="session-alert">
            <:icon><.icon_warning /></:icon>
            <.alert_description>{@flash["error"]}</.alert_description>
          </.alert>

          <%= case @step do %>
            <% :nickname -> %>
              <.nickname_step
                nickname={@nickname}
                nickname_error={@nickname_error}
              />
            <% :password -> %>
              <.password_step
                nickname={@nickname}
                password={@password}
                password_error={@password_error}
              />
            <% :register -> %>
              <.register_step
                nickname={@nickname}
                password={@password}
                password_confirm={@password_confirm}
                password_error={@password_error}
              />
          <% end %>
        </.window_body>
      </.window>

      <form id="connect-session-form" action={~p"/v2/chat/session"} method="post" class="hidden">
        <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
        <input type="hidden" name="nickname" value={@nickname} />
        <input :if={@auth_token} type="hidden" name="auth_token" value={@auth_token} />
        <input type="hidden" name="timezone" id="connect-timezone-input" value="Etc/UTC" />
      </form>
    </div>
    """
  end

  attr :nickname, :string, required: true
  attr :nickname_error, :string, default: nil

  defp nickname_step(assigns) do
    ~H"""
    <form phx-submit="connect" phx-change="validate">
      <.retro_fieldset legend="User Information">
        <.field_row stacked>
          <.label for="nickname">
            <.icon_status_user class="w-3.5 h-3.5 inline-block" /> Nickname
          </.label>
          <.input
            type="text"
            id="nickname"
            name="nickname"
            value={@nickname}
            maxlength="16"
            autocomplete="off"
            placeholder="Enter your nickname..."
            phx-debounce="300"
            phx-mounted={JS.focus()}
          />
        </.field_row>
        <ul class="text-xs mt-2 space-y-0.5 text-muted-foreground">
          <li><.icon_checkmark class="w-3 h-3 inline-block" /> 1–16 characters</li>
          <li><.icon_checkmark class="w-3 h-3 inline-block" /> Must start with a letter</li>
          <li><.icon_checkmark class="w-3 h-3 inline-block" /> No spaces allowed</li>
          <li><.icon_checkmark class="w-3 h-3 inline-block" /> Case sensitive</li>
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
          Connect
        </.button>
      </div>

      <div class="mt-4 space-y-2 text-xs">
        <div class="flex gap-2 items-start p-2 bg-canvas shadow-retro-field">
          <.icon_connect class="w-3.5 h-3.5 shrink-0 mt-0.5" />
          <div>
            <strong>One session per nickname</strong>
            <p class="text-muted-foreground">
              Connecting from another window ends the previous session.
            </p>
          </div>
        </div>
        <div class="flex gap-2 items-start p-2 bg-canvas shadow-retro-field">
          <.icon_clock class="w-3.5 h-3.5 shrink-0 mt-0.5" />
          <div>
            <strong>Session expiry</strong>
            <p class="text-muted-foreground">
              Sessions expire after 10 failed reconnection attempts.
            </p>
          </div>
        </div>
        <div
          class="flex gap-2 items-start p-2 bg-canvas shadow-retro-field"
          data-testid="nick-expiry-notice"
        >
          <.icon_warning class="w-3.5 h-3.5 shrink-0 mt-0.5" />
          <div>
            <strong>Nickname cleanup</strong>
            <p class="text-muted-foreground">
              Nicknames unused for 7 days are automatically released.
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
    <form phx-submit="authenticate" phx-change="validate_password">
      <.retro_fieldset legend="Authentication">
        <.alert class="mb-3">
          <:icon><.icon_shield /></:icon>
          <.alert_description>
            The nickname <strong>{@nickname}</strong>
            is registered. Please enter your password to continue.
          </.alert_description>
        </.alert>

        <.field_row stacked>
          <.label for="password">
            <.icon_lock class="w-3.5 h-3.5 inline-block" /> Password
          </.label>
          <.input
            type="text"
            class="input-masked"
            id="password"
            name="password"
            value={@password}
            placeholder="Enter your password..."
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
          Back
        </.button>
        <.button type="submit" data-testid="auth-btn" disabled={@password == ""}>
          <:icon><.icon_connect /></:icon>
          Connect
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
    <form phx-submit="register" phx-change="validate_register">
      <.retro_fieldset legend="Registration">
        <.alert class="mb-3">
          <:icon><.icon_checkmark /></:icon>
          <.alert_description>
            The nickname <strong>{@nickname}</strong> is available! Choose a password to register it.
          </.alert_description>
        </.alert>

        <.field_row stacked class="mb-2">
          <.label for="reg-password">
            <.icon_lock class="w-3.5 h-3.5 inline-block" /> Password
          </.label>
          <.input
            type="text"
            class="input-masked"
            id="reg-password"
            name="password"
            value={@password}
            placeholder="Choose a password (min. 5 characters)..."
            phx-mounted={JS.focus()}
          />
        </.field_row>

        <.field_row stacked>
          <.label for="reg-password-confirm">
            <.icon_lock class="w-3.5 h-3.5 inline-block" /> Confirm password
          </.label>
          <.input
            type="text"
            class="input-masked"
            id="reg-password-confirm"
            name="password_confirm"
            value={@password_confirm}
            placeholder="Repeat your password..."
          />
        </.field_row>
        <p :if={@password_error} class="text-destructive text-xs mt-2">
          <.icon_reject class="w-3 h-3 inline-block" /> {@password_error}
        </p>
      </.retro_fieldset>

      <div class="flex justify-end gap-2 mt-4">
        <.button type="button" variant="outline" phx-click="back" data-testid="back-btn">
          <:icon><.icon_btn_prev /></:icon>
          Back
        </.button>
        <.button
          type="submit"
          data-testid="register-btn"
          disabled={@password == "" or @password_confirm == ""}
        >
          <:icon><.icon_connect /></:icon>
          Register &amp; Connect
        </.button>
      </div>
    </form>
    """
  end
end
