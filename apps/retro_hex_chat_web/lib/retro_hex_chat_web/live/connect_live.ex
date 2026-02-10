defmodule RetroHexChatWeb.ConnectLive do
  @moduledoc """
  Win98-style connection dialog. Users enter nickname, validate, and connect.
  """
  use RetroHexChatWeb, :live_view

  alias RetroHexChat.Accounts.NicknameValidator

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       nickname: "",
       nickname_error: nil,
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
        {:noreply, push_navigate(socket, to: ~p"/chat?nickname=#{nickname}")}

      {:error, msg} ->
        {:noreply, assign(socket, nickname_error: msg)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="connect-dialog">
      <div class="window">
        <div class="title-bar">
          <div class="title-bar-text">Connect to RetroHexChat</div>
          <div class="title-bar-controls">
            <button aria-label="Close"></button>
          </div>
        </div>
        <div class="window-body">
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
        </div>
      </div>
    </div>
    """
  end
end
