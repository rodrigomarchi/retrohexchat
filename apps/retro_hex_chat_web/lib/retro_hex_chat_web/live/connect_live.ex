defmodule RetroHexChatWeb.ConnectLive do
  @moduledoc """
  Win98-style connection dialog. Users enter nickname and connect.
  If the nickname is registered, a password step is shown for inline authentication.
  """
  use RetroHexChatWeb, :live_view

  alias RetroHexChat.Accounts.NicknameValidator
  alias RetroHexChat.Services.NickServ

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       nickname: "",
       nickname_error: nil,
       password: "",
       password_error: nil,
       step: :nickname,
       page_title: "Connect - RetroHexChat"
     )}
  end

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
          {:noreply, push_navigate(socket, to: ~p"/chat?nickname=#{nickname}")}
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
         push_navigate(socket,
           to: ~p"/chat?nickname=#{nickname}&auth_token=#{token}"
         )}

      {:error, _msg} ->
        {:noreply, assign(socket, password_error: "Senha incorreta", password: "")}
    end
  end

  def handle_event("back", _params, socket) do
    {:noreply, assign(socket, step: :nickname, password: "", password_error: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="connect-dialog" id="connect-root">
      <div class="window">
        <div class="title-bar">
          <div class="title-bar-text">Connect to RetroHexChat</div>
          <div class="title-bar-controls">
            <button aria-label="Close"></button>
          </div>
        </div>
        <div class="window-body">
          <%= if @step == :nickname do %>
            <form phx-submit="connect" phx-change="validate">
              <fieldset>
                <legend>User Information</legend>
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
                />
                <p :if={@nickname_error} class="error-text">{@nickname_error}</p>
              </fieldset>
              <div class="button-row">
                <button
                  type="submit"
                  data-testid="connect-btn"
                  disabled={@nickname_error != nil or @nickname == ""}
                >
                  Connect
                </button>
              </div>
            </form>
          <% else %>
            <form phx-submit="authenticate" phx-change="validate_password">
              <fieldset>
                <legend>Authentication</legend>
                <p class="auth-info">
                  The nickname <strong>{@nickname}</strong> is registered. Please enter your password.
                </p>
                <label for="password">Password:</label>
                <input
                  type="password"
                  id="password"
                  name="password"
                  value={@password}
                  autofocus
                  autocomplete="off"
                />
                <p :if={@password_error} class="error-text">{@password_error}</p>
              </fieldset>
              <div class="button-row">
                <button type="button" phx-click="back" data-testid="back-btn">
                  &lt; Back
                </button>
                <button type="submit" data-testid="auth-btn" disabled={@password == ""}>
                  Connect
                </button>
              </div>
            </form>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
