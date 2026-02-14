defmodule RetroHexChatWeb.ConnectLive do
  @moduledoc """
  Win98-style connection dialog. Users enter nickname, validate, and connect.
  First-time users see a 3-step wizard; returning users see the simple form.
  """
  use RetroHexChatWeb, :live_view

  alias RetroHexChat.Accounts.NicknameValidator
  alias RetroHexChatWeb.ConnectLive.WizardEvents

  import RetroHexChatWeb.Components.WizardDialog

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       nickname: "",
       nickname_error: nil,
       page_title: "Connect - RetroHexChat",
       wizard_mode: false,
       wizard_step: :welcome,
       wizard_nickname: "",
       wizard_server: "irc.retro.chat",
       wizard_port: 6697,
       wizard_ssl: true,
       wizard_connecting: false,
       wizard_connect_error: nil,
       wizard_channels: [],
       wizard_selected_channels: [],
       wizard_custom_channel: ""
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

  # Delegate all wizard events
  def handle_event("check_onboarding" = event, params, socket),
    do: WizardEvents.handle_event(event, params, socket)

  def handle_event("wizard_" <> _ = event, params, socket),
    do: WizardEvents.handle_event(event, params, socket)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="connect-dialog" id="connect-root" phx-hook="OnboardingHook">
      <.wizard_dialog
        visible={@wizard_mode}
        step={@wizard_step}
        nickname={@wizard_nickname}
        nickname_error={@nickname_error}
        server={@wizard_server}
        port={@wizard_port}
        ssl={@wizard_ssl}
        connecting={@wizard_connecting}
        connect_error={@wizard_connect_error}
        channels={@wizard_channels}
        selected_channels={@wizard_selected_channels}
        custom_channel={@wizard_custom_channel}
      />

      <div :if={!@wizard_mode} class="window">
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
