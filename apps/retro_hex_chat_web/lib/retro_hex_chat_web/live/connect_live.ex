defmodule RetroHexChatWeb.ConnectLive do
  @moduledoc """
  Win98-style connection dialog. Users enter nickname and connect.
  If the nickname is registered, a password step is shown for inline authentication.

  On successful validation, a hidden form is submitted via POST to `/chat/session`,
  which stores credentials in the encrypted session cookie and redirects to `/chat`.
  """
  use RetroHexChatWeb, :live_view

  import RetroHexChatWeb.Icons

  alias Phoenix.LiveView.JS

  alias RetroHexChat.Accounts.NicknameValidator
  alias RetroHexChat.Services.NickServ

  @impl true
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
  defp reason_to_message("expired"), do: "Sessão expirada"
  defp reason_to_message("disconnected"), do: "Sessão encerrada"
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
        {:noreply, assign(socket, password_error: "Senha incorreta", password: "")}
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
  def render(assigns) do
    ~H"""
    <div class="app-container" id="connect-root" phx-hook="ConnectFormHook">
      <RetroHexChatWeb.Components.AppHeader.app_header>
        <:panels>
          <div class="toolbar toolbar--skeleton">
            <span class="toolbar-btn toolbar-btn--skeleton"></span>
            <span class="toolbar-btn toolbar-btn--skeleton"></span>
            <span class="toolbar-btn toolbar-btn--skeleton"></span>
            <span class="toolbar-btn toolbar-btn--skeleton"></span>
            <span class="toolbar-btn toolbar-btn--skeleton"></span>
            <span class="toolbar-btn toolbar-btn--skeleton"></span>
            <span class="toolbar-btn toolbar-btn--skeleton"></span>
            <span class="toolbar-btn toolbar-btn--skeleton"></span>
          </div>
          <div class="status-bar status-bar--skeleton">
            <p class="status-bar-field">&nbsp;</p>
            <p class="status-bar-field">&nbsp;</p>
            <p class="status-bar-field">&nbsp;</p>
          </div>
        </:panels>
      </RetroHexChatWeb.Components.AppHeader.app_header>
      <div class="connect-dialog">
        <p :if={@flash["error"]} class="error-text" data-testid="session-alert">
          {@flash["error"]}
        </p>
        <div class="window">
          <div class="title-bar">
            <div class="title-bar-text">Connect to RetroHexChat</div>
            <div class="title-bar-controls">
              <button aria-label="Close"></button>
            </div>
          </div>
          <div class="window-body">
            <%= case @step do %>
              <% :nickname -> %>
                <form phx-submit="connect" phx-change="validate">
                  <fieldset>
                    <legend><.icon_chat class="licon licon-14" /> User Information</legend>
                    <label for="nickname">Nickname:</label>
                    <input
                      type="text"
                      id="nickname"
                      name="nickname"
                      value={@nickname}
                      maxlength="16"
                      autofocus
                      autocomplete="off"
                      phx-debounce="300"
                      phx-mounted={JS.focus()}
                    />
                    <p class="nick-help">
                      1–16 characters. Must start with a letter. No spaces. Case sensitive.
                    </p>
                    <p :if={@nickname_error} class="error-text">{@nickname_error}</p>
                  </fieldset>
                  <div class="button-row">
                    <button
                      type="submit"
                      data-testid="connect-btn"
                      disabled={@nickname_error != nil or @nickname == ""}
                    >
                      <.icon_connect class="licon licon-14" /> Connect
                    </button>
                  </div>
                  <p class="session-info">
                    Apenas uma sessão por nickname é permitida. Conectar em outra janela
                    encerra a sessão anterior. A sessão expira após 10 tentativas de reconexão
                    sem sucesso.
                  </p>
                </form>
              <% :password -> %>
                <form phx-submit="authenticate" phx-change="validate_password">
                  <fieldset>
                    <legend><.icon_lock class="licon licon-14" /> Authentication</legend>
                    <p class="auth-info">
                      The nickname <strong>{@nickname}</strong>
                      is registered. Please enter your password.
                    </p>
                    <label for="password">Password:</label>
                    <input
                      type="password"
                      id="password"
                      name="password"
                      value={@password}
                      autofocus
                      autocomplete="off"
                      phx-mounted={JS.focus()}
                    />
                    <p :if={@password_error} class="error-text">{@password_error}</p>
                  </fieldset>
                  <div class="button-row">
                    <button type="button" phx-click="back" data-testid="back-btn">
                      &lt; Back
                    </button>
                    <button type="submit" data-testid="auth-btn" disabled={@password == ""}>
                      <.icon_connect class="licon licon-14" /> Connect
                    </button>
                  </div>
                </form>
              <% :register -> %>
                <form phx-submit="register" phx-change="validate_register">
                  <fieldset>
                    <legend><.icon_notepad class="licon licon-14" /> Registration</legend>
                    <p class="auth-info">
                      The nickname <strong>{@nickname}</strong>
                      is available. Choose a password to register it.
                    </p>
                    <label for="reg-password">Password:</label>
                    <input
                      type="password"
                      id="reg-password"
                      name="password"
                      value={@password}
                      autocomplete="off"
                      phx-mounted={JS.focus()}
                    />
                    <label for="reg-password-confirm">Confirm password:</label>
                    <input
                      type="password"
                      id="reg-password-confirm"
                      name="password_confirm"
                      value={@password_confirm}
                      autocomplete="off"
                    />
                    <p :if={@password_error} class="error-text">{@password_error}</p>
                  </fieldset>
                  <div class="button-row">
                    <button type="button" phx-click="back" data-testid="back-btn">
                      &lt; Back
                    </button>
                    <button
                      type="submit"
                      data-testid="register-btn"
                      disabled={@password == "" or @password_confirm == ""}
                    >
                      <.icon_connect class="licon licon-14" /> Register &amp; Connect
                    </button>
                  </div>
                </form>
            <% end %>
          </div>
        </div>
        <form id="connect-session-form" action={~p"/chat/session"} method="post" class="u-hidden">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <input type="hidden" name="nickname" value={@nickname} />
          <input :if={@auth_token} type="hidden" name="auth_token" value={@auth_token} />
        </form>
      </div>
    </div>
    """
  end
end
