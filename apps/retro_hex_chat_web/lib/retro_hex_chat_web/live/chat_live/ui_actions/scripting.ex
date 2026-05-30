defmodule RetroHexChatWeb.ChatLive.UiActions.Scripting do
  @moduledoc """
  Scripting UI actions: custom menus dialog, autorespond CRUD, timer management.
  """

  import Phoenix.Component, only: [assign: 2]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [system_event: 2, error_event: 2, maybe_persist_autorespond_rules: 2]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{AutoRespondRules, TimerManager}

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :open_custom_menus_dialog, _payload) do
    assign(socket, show_custom_menus_dialog: true)
  end

  def handle_ui_action(socket, :open_autorespond_dialog, _payload) do
    assign(socket, show_autorespond_dialog: true)
  end

  def handle_ui_action(socket, :autorespond_added, %{
        trigger_event: trigger,
        channel_filter: channel,
        command: command
      }) do
    session = socket.assigns.session

    case AutoRespondRules.add_entry(session.autorespond_rules, trigger, channel, command) do
      {:ok, updated} ->
        new_session = Session.set_autorespond_rules(session, updated)

        socket
        |> assign(session: new_session)
        |> maybe_persist_autorespond_rules(new_session)
        |> system_event("Auto-respond rule added: #{trigger} → #{command}")

      {:error, reason} ->
        system_event(
          socket,
          "Error adding auto-respond rule: #{autorespond_error_msg(reason)}"
        )
    end
  end

  def handle_ui_action(socket, :autorespond_removed, %{position: position}) do
    session = socket.assigns.session

    case AutoRespondRules.remove_entry(session.autorespond_rules, position) do
      {:ok, updated} ->
        new_session = Session.set_autorespond_rules(session, updated)

        socket
        |> assign(session: new_session)
        |> maybe_persist_autorespond_rules(new_session)
        |> system_event("Auto-respond rule removed.")

      {:error, :not_found} ->
        system_event(socket, "Auto-respond rule not found.")
    end
  end

  def handle_ui_action(socket, :autorespond_list_display, _payload) do
    session = socket.assigns.session
    entries = AutoRespondRules.entries(session.autorespond_rules)

    if entries == [] do
      system_event(socket, "No auto-respond rules configured.")
    else
      lines = Enum.map(entries, &format_autorespond_entry/1)
      msg = ["Auto-respond rules:" | lines] |> Enum.join("\n")
      system_event(socket, msg)
    end
  end

  def handle_ui_action(socket, :timer_create, %{
        name: name,
        type: type,
        interval: interval,
        command: command
      }) do
    timers = socket.assigns.user_timers
    session = socket.assigns.session

    case TimerManager.validate_create(timers, name, type, interval, command) do
      :ok ->
        {clamped_interval, notice} = TimerManager.clamp_interval(type, interval)

        socket =
          case Map.get(timers, name) do
            %{ref: ref} ->
              Process.cancel_timer(ref)
              socket

            nil ->
              socket
          end

        ref = Process.send_after(self(), {:user_timer_fired, name}, clamped_interval * 1000)

        new_timers =
          Map.put(timers, name, %{
            type: type,
            interval: clamped_interval,
            command: command,
            window: active_window(socket, session),
            ref: ref
          })

        socket = assign(socket, user_timers: new_timers)

        socket =
          if notice do
            system_event(socket, "* #{notice}")
          else
            socket
          end

        type_label = if type == :repeat, do: "repeat", else: "one-shot"

        system_event(
          socket,
          "* Timer '#{name}' set: #{type_label}, #{clamped_interval}s → #{command}"
        )

      {:error, msg} ->
        error_event(socket, msg)
    end
  end

  def handle_ui_action(socket, :timer_stop, %{name: name}) do
    timers = socket.assigns.user_timers

    case Map.get(timers, name) do
      %{ref: ref} ->
        Process.cancel_timer(ref)
        new_timers = Map.delete(timers, name)

        socket
        |> assign(user_timers: new_timers)
        |> system_event("* Timer '#{name}' stopped")

      nil ->
        error_event(socket, "Timer '#{name}' not found")
    end
  end

  def handle_ui_action(socket, :timer_list, _payload) do
    text = TimerManager.format_timer_list(socket.assigns.user_timers)

    text
    |> String.split("\n")
    |> Enum.reduce(socket, fn line, acc ->
      system_event(acc, line)
    end)
  end

  # Private helpers

  defp format_autorespond_entry(entry) do
    status = if entry.enabled, do: "[ON]", else: "[OFF]"
    channel = entry.channel_filter || "(all)"
    "  #{entry.position}: #{status} #{entry.trigger_event} #{channel} → #{entry.command}"
  end

  defp autorespond_error_msg(:list_full), do: "Maximum 10 auto-respond rules"
  defp autorespond_error_msg(:invalid_trigger), do: "Invalid trigger event"
  defp autorespond_error_msg(:invalid_channel), do: "Channel filter must start with #"
  defp autorespond_error_msg(:invalid_command), do: "Command is required"
  defp autorespond_error_msg(:command_too_long), do: "Command too long (max 500 characters)"

  defp autorespond_error_msg(:command_chaining),
    do: "Command must not contain chaining (|, &&, ;)"

  defp active_window(socket, session) do
    cond do
      socket.assigns.show_status_tab -> :status
      session.active_pm -> {:pm, session.active_pm}
      session.active_channel -> {:channel, session.active_channel}
      true -> nil
    end
  end
end
