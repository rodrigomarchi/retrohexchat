defmodule RetroHexChatWeb.ConnectLive.WizardEvents do
  @moduledoc """
  Wizard event handlers for ConnectLive.

  Handles all wizard navigation, validation, and completion events.
  Called from ConnectLive via delegated handle_event clauses.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_navigate: 2, push_event: 3]

  alias RetroHexChat.Accounts.NicknameValidator

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("check_onboarding", %{"first_visit" => true}, socket) do
    {:noreply, assign(socket, wizard_mode: true, wizard_step: :welcome)}
  end

  def handle_event("check_onboarding", %{"first_visit" => false}, socket) do
    {:noreply, assign(socket, wizard_mode: false)}
  end

  def handle_event("wizard_validate_nickname", %{"nickname" => nickname}, socket) do
    error =
      case NicknameValidator.validate(nickname) do
        :ok -> nil
        {:error, msg} -> msg
      end

    {:noreply, assign(socket, wizard_nickname: nickname, nickname_error: error)}
  end

  def handle_event("wizard_next", %{"step" => "welcome"}, socket) do
    case NicknameValidator.validate(socket.assigns.wizard_nickname) do
      :ok ->
        {:noreply, assign(socket, wizard_step: :server, nickname_error: nil)}

      {:error, msg} ->
        {:noreply, assign(socket, nickname_error: msg)}
    end
  end

  def handle_event("wizard_next", %{"step" => "server"}, socket) do
    # For now, skip actual connection attempt and move to channels step.
    # The real connection happens when the user completes the wizard
    # and navigates to ChatLive (which handles the actual IRC connection).
    {:noreply, assign(socket, wizard_step: :channels, wizard_connect_error: nil)}
  end

  def handle_event("wizard_back", %{"step" => "server"}, socket) do
    {:noreply, assign(socket, wizard_step: :welcome)}
  end

  def handle_event("wizard_back", %{"step" => "channels"}, socket) do
    {:noreply, assign(socket, wizard_step: :server)}
  end

  def handle_event("wizard_toggle_channel", %{"channel" => channel}, socket) do
    selected = socket.assigns.wizard_selected_channels

    updated =
      if channel in selected do
        List.delete(selected, channel)
      else
        [channel | selected]
      end

    {:noreply, assign(socket, wizard_selected_channels: updated)}
  end

  def handle_event("wizard_update_custom_channel", %{"channel" => channel}, socket) do
    {:noreply, assign(socket, wizard_custom_channel: channel)}
  end

  def handle_event("wizard_complete", _params, socket) do
    nickname = socket.assigns.wizard_nickname
    selected = socket.assigns.wizard_selected_channels
    custom = socket.assigns.wizard_custom_channel

    channels =
      if custom != "" and String.starts_with?(custom, "#") do
        Enum.uniq(selected ++ [custom])
      else
        selected
      end

    join_param = Enum.join(channels, ",")

    path =
      if join_param != "" do
        "/chat?nickname=#{URI.encode_www_form(nickname)}&join=#{URI.encode_www_form(join_param)}&onboarded=true"
      else
        "/chat?nickname=#{URI.encode_www_form(nickname)}&onboarded=true"
      end

    socket =
      socket
      |> push_event("mark_onboarding_complete", %{})
      |> push_navigate(to: path)

    {:noreply, socket}
  end

  def handle_event("wizard_skip", _params, socket) do
    nickname = socket.assigns.wizard_nickname

    socket =
      socket
      |> push_event("mark_onboarding_complete", %{})
      |> push_navigate(to: "/chat?nickname=#{URI.encode_www_form(nickname)}&onboarded=true")

    {:noreply, socket}
  end

  def handle_event("wizard_dismiss", _params, socket) do
    socket =
      socket
      |> push_event("mark_onboarding_complete", %{})
      |> assign(wizard_mode: false)

    {:noreply, socket}
  end
end
