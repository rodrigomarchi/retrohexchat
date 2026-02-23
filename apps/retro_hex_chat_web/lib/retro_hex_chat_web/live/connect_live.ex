defmodule RetroHexChatWeb.ConnectLive do
  @moduledoc """
  Retro-style connection dialog. Users enter nickname and connect.
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
  def render(assigns) do
    ~H"""
    <div class="app-container" id="connect-root" phx-hook="ConnectFormHook">
      <RetroHexChatWeb.Components.AppHeader.app_header>
        <:panels>
          <div
            class="toolbar toolbar--preview"
            role="toolbar"
            id="connect-toolbar"
            phx-hook="ToolbarGroupHook"
          >
            <%!-- Connection (disabled — not connected yet) --%>
            <span class="toolbar-btn toolbar-btn--disabled" title="Connect">
              <svg viewBox="0 0 16 16">
                <circle cx="4" cy="8" r="2.5" fill="#999" />
                <circle cx="12" cy="8" r="2.5" fill="#999" />
                <path d="M7 6l2-2 2 2-1 1-1-1v6l1-1 1 1-2 2-2-2 1-1 1 1V6L7 7z" fill="#bbb" />
              </svg>
            </span>
            <%!-- View group --%>
            <span class="toolbar-btn toolbar-btn--disabled" title="View">
              <.icon_group_view class="toolbar-group-icon toolbar-icon--disabled" />
            </span>
            <%!-- Tools group --%>
            <span class="toolbar-btn toolbar-btn--disabled" title="Tools">
              <.icon_group_tools class="toolbar-group-icon toolbar-icon--disabled" />
            </span>
            <%!-- Notifications group --%>
            <span class="toolbar-btn toolbar-btn--disabled" title="Notifications">
              <.icon_group_notifications class="toolbar-group-icon toolbar-icon--disabled" />
            </span>
            <%!-- Help group (ACTIVE — links work on connect page) --%>
            <div class="toolbar-group">
              <button
                type="button"
                class="toolbar-btn toolbar-group-toggle"
                data-toolbar-group="help"
                title="Help"
              >
                <.icon_group_help class="toolbar-group-icon" />
              </button>
              <div class="toolbar-group-dropdown u-hidden">
                <a
                  class="toolbar-btn"
                  title="Help Topics"
                  href="/chat/help"
                  target="_blank"
                >
                  <svg viewBox="0 0 16 16">
                    <circle cx="8" cy="8" r="7" fill="#000080" />
                    <text
                      x="8"
                      y="12"
                      text-anchor="middle"
                      font-size="11"
                      font-weight="bold"
                      font-family="sans-serif"
                      fill="#fff"
                    >
                      ?
                    </text>
                  </svg>
                  <span class="toolbar-group-label">Help Topics</span>
                </a>
              </div>
            </div>
          </div>
          <div class="status-bar">
            <p class="status-bar-field status-bar-section--left">
              <.icon_status_user class="status-bar-icon status-bar-icon--disabled" />
              <span class="status-bar-nick status-bar-text--disabled">Guest</span>
              <span class="status-bar-separator">|</span>
              <.icon_tab_channel class="status-bar-icon status-bar-icon--disabled" />
              <span class="status-bar-channel status-bar-text--disabled">No channel</span>
              <span class="status-bar-text--disabled">(0)</span>
              <span class="status-bar-separator">|</span>
              <span class="status-bar-connection--disconnected">● Off</span>
              <span class="status-bar-separator">|</span>
              <.icon_status_signal class="status-bar-icon status-bar-icon--disabled" />
              <span class="status-bar-text--disabled">Lag: —</span>
              <span class="status-bar-separator">|</span>
              <.icon_clock class="status-bar-icon status-bar-icon--disabled" />
              <span
                id="clock-display"
                phx-hook="ClockHook"
                data-testid="status-clock"
              >
                --:--
              </span>
              <span class="status-bar-separator">|</span>
              <span class="status-bar-text--disabled">
                <.icon_dialog_sound class="status-bar-icon status-bar-icon--disabled" />
              </span>
            </p>
          </div>
        </:panels>
      </RetroHexChatWeb.Components.AppHeader.app_header>
      <div class="connect-dialog">
        <div class="window">
          <div class="title-bar">
            <div class="title-bar-text">Connect to RetroHexChat</div>
            <div class="title-bar-controls">
              <button aria-label="Close"></button>
            </div>
          </div>
          <div class="window-body">
            <div :if={@flash["error"]} class="session-alert" data-testid="session-alert">
              <.icon_warning class="licon licon-16" />
              <span>{@flash["error"]}</span>
            </div>
            <%= case @step do %>
              <% :nickname -> %>
                <form phx-submit="connect" phx-change="validate">
                  <fieldset>
                    <legend><.icon_dialog_nick class="licon licon-16" /> User Information</legend>
                    <div class="connect-field">
                      <label for="nickname">
                        <.icon_status_user class="licon licon-14" /> Nickname:
                      </label>
                      <input
                        type="text"
                        id="nickname"
                        name="nickname"
                        value={@nickname}
                        maxlength="16"
                        autofocus
                        autocomplete="off"
                        placeholder="Enter your nickname..."
                        phx-debounce="300"
                        phx-mounted={JS.focus()}
                      />
                      <ul class="nick-rules">
                        <li>
                          <.icon_checkmark class="licon licon-12" /> 1–16 characters
                        </li>
                        <li>
                          <.icon_checkmark class="licon licon-12" /> Must start with a letter
                        </li>
                        <li>
                          <.icon_checkmark class="licon licon-12" /> No spaces allowed
                        </li>
                        <li>
                          <.icon_checkmark class="licon licon-12" /> Case sensitive
                        </li>
                      </ul>
                      <p :if={@nickname_error} class="error-text">
                        <.icon_reject class="licon licon-12" /> {@nickname_error}
                      </p>
                    </div>
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
                  <div class="connect-footer">
                    <div class="connect-notice">
                      <.icon_connect class="licon licon-14 connect-notice-icon" />
                      <div>
                        <strong>One session per nickname</strong>
                        <p>
                          Connecting from another window ends the previous session.
                        </p>
                      </div>
                    </div>
                    <div class="connect-notice">
                      <.icon_clock class="licon licon-14 connect-notice-icon" />
                      <div>
                        <strong>Session expiry</strong>
                        <p>
                          Sessions expire after 10 failed reconnection attempts.
                        </p>
                      </div>
                    </div>
                    <div class="connect-notice" data-testid="nick-expiry-notice">
                      <.icon_warning class="licon licon-14 connect-notice-icon" />
                      <div>
                        <strong>Nickname cleanup</strong>
                        <p>
                          Nicknames unused for 7 days are automatically released.
                        </p>
                      </div>
                    </div>
                  </div>
                </form>
              <% :password -> %>
                <form phx-submit="authenticate" phx-change="validate_password">
                  <fieldset>
                    <legend><.icon_lock class="licon licon-16" /> Authentication</legend>
                    <div class="auth-banner">
                      <.icon_shield class="licon licon-16 auth-banner-icon" />
                      <p class="auth-info">
                        The nickname <strong>{@nickname}</strong>
                        is registered. Please enter your password to continue.
                      </p>
                    </div>
                    <div class="connect-field">
                      <label for="password">
                        <.icon_lock class="licon licon-14" /> Password:
                      </label>
                      <input
                        type="text"
                        class="input-masked"
                        id="password"
                        name="password"
                        value={@password}
                        autofocus
                        placeholder="Enter your password..."
                        phx-mounted={JS.focus()}
                      />
                      <p :if={@password_error} class="error-text">
                        <.icon_reject class="licon licon-12" /> {@password_error}
                      </p>
                    </div>
                  </fieldset>
                  <div class="button-row">
                    <button type="button" phx-click="back" data-testid="back-btn">
                      <.icon_btn_prev class="licon licon-14" /> Back
                    </button>
                    <button type="submit" data-testid="auth-btn" disabled={@password == ""}>
                      <.icon_connect class="licon licon-14" /> Connect
                    </button>
                  </div>
                </form>
              <% :register -> %>
                <form phx-submit="register" phx-change="validate_register">
                  <fieldset>
                    <legend><.icon_notepad class="licon licon-16" /> Registration</legend>
                    <div class="auth-banner auth-banner--success">
                      <.icon_checkmark class="licon licon-16 auth-banner-icon" />
                      <p class="auth-info">
                        The nickname <strong>{@nickname}</strong>
                        is available! Choose a password to register it.
                      </p>
                    </div>
                    <div class="connect-field">
                      <label for="reg-password">
                        <.icon_lock class="licon licon-14" /> Password:
                      </label>
                      <input
                        type="text"
                        class="input-masked"
                        id="reg-password"
                        name="password"
                        value={@password}
                        placeholder="Choose a password (min. 5 characters)..."
                        phx-mounted={JS.focus()}
                      />
                    </div>
                    <div class="connect-field">
                      <label for="reg-password-confirm">
                        <.icon_lock class="licon licon-14" /> Confirm password:
                      </label>
                      <input
                        type="text"
                        class="input-masked"
                        id="reg-password-confirm"
                        name="password_confirm"
                        value={@password_confirm}
                        placeholder="Repeat your password..."
                      />
                    </div>
                    <p :if={@password_error} class="error-text">
                      <.icon_reject class="licon licon-12" /> {@password_error}
                    </p>
                  </fieldset>
                  <div class="button-row">
                    <button type="button" phx-click="back" data-testid="back-btn">
                      <.icon_btn_prev class="licon licon-14" /> Back
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
          <input type="hidden" name="timezone" id="connect-timezone-input" value="Etc/UTC" />
        </form>
      </div>
    </div>
    """
  end
end
