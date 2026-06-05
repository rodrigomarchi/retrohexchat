defmodule RetroHexChatWeb.ChatLive.UiActions.Scripting do
  @moduledoc """
  Scripting UI actions: custom menus dialog, autorespond CRUD, timer management.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

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

  def handle_ui_action(socket, :open_timers_dialog, _payload) do
    assign(socket, show_timers_dialog: true)
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
        |> system_event(
          dgettext("chat", "Auto-respond rule added: %{trigger} → %{command}",
            trigger: trigger,
            command: command
          )
        )

      {:error, reason} ->
        system_event(
          socket,
          dgettext("chat", "Error adding auto-respond rule: %{message}",
            message: autorespond_error_msg(reason)
          )
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
        |> system_event(dgettext("chat", "Auto-respond rule removed."))

      {:error, :not_found} ->
        system_event(socket, dgettext("chat", "Auto-respond rule not found."))
    end
  end

  def handle_ui_action(socket, :autorespond_list_display, _payload) do
    session = socket.assigns.session
    entries = AutoRespondRules.entries(session.autorespond_rules)

    if entries == [] do
      system_event(socket, dgettext("chat", "No auto-respond rules configured."))
    else
      lines = Enum.map(entries, &format_autorespond_entry/1)
      msg = [dgettext("chat", "Auto-respond rules:") | lines] |> Enum.join("\n")
      system_event(socket, msg)
    end
  end

  def handle_ui_action(socket, :timer_create, %{
        name: name,
        type: type,
        interval: interval,
        command: command
      }) do
    case create_timer(socket, name, type, interval, command) do
      {:ok, socket} -> socket
      {:error, socket, message} -> error_event(socket, message)
    end
  end

  def handle_ui_action(socket, :timer_stop, %{name: name}) do
    case stop_timer(socket, name) do
      {:ok, socket} -> socket
      {:error, socket, message} -> error_event(socket, message)
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

  @spec create_timer(
          Phoenix.LiveView.Socket.t(),
          String.t(),
          :once | :repeat,
          integer(),
          String.t()
        ) ::
          {:ok, Phoenix.LiveView.Socket.t()} | {:error, Phoenix.LiveView.Socket.t(), String.t()}
  def create_timer(socket, name, type, interval, command) do
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
            system_event(socket, dgettext("chat", "* %{notice}", notice: notice))
          else
            socket
          end

        type_label =
          if type == :repeat, do: dgettext("chat", "repeat"), else: dgettext("chat", "one-shot")

        system_event(
          socket,
          dgettext("chat", "* Timer '%{name}' set: %{type}, %{interval}s → %{command}",
            name: name,
            type: type_label,
            interval: clamped_interval,
            command: command
          )
        )
        |> then(&{:ok, &1})

      {:error, msg} ->
        {:error, socket, msg}
    end
  end

  @spec stop_timer(Phoenix.LiveView.Socket.t(), String.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()} | {:error, Phoenix.LiveView.Socket.t(), String.t()}
  def stop_timer(socket, name) do
    timers = socket.assigns.user_timers

    case Map.get(timers, name) do
      %{ref: ref} ->
        Process.cancel_timer(ref)
        new_timers = Map.delete(timers, name)

        socket
        |> assign(user_timers: new_timers)
        |> system_event(dgettext("chat", "* Timer '%{name}' stopped", name: name))
        |> then(&{:ok, &1})

      nil ->
        {:error, socket, dgettext("chat", "Timer '%{name}' not found", name: name)}
    end
  end

  # Private helpers

  defp format_autorespond_entry(entry) do
    status = if entry.enabled, do: "[ON]", else: "[OFF]"
    channel = entry.channel_filter || dgettext("chat", "(all)")

    dgettext("chat", "  %{position}: %{status} %{trigger} %{channel} → %{command}",
      position: entry.position,
      status: status,
      trigger: entry.trigger_event,
      channel: channel,
      command: entry.command
    )
  end

  defp autorespond_error_msg(:list_full), do: dgettext("chat", "Maximum 10 auto-respond rules")
  defp autorespond_error_msg(:invalid_trigger), do: dgettext("chat", "Invalid trigger event")

  defp autorespond_error_msg(:invalid_channel),
    do: dgettext("chat", "Channel filter must start with #")

  defp autorespond_error_msg(:invalid_command), do: dgettext("chat", "Command is required")

  defp autorespond_error_msg(:command_too_long),
    do: dgettext("chat", "Command too long (max 500 characters)")

  defp autorespond_error_msg(:command_chaining),
    do: dgettext("chat", "Command must not contain chaining (|, &&, ;)")

  defp active_window(socket, session) do
    cond do
      socket.assigns.show_status_tab -> :status
      session.active_pm -> {:pm, session.active_pm}
      session.active_channel -> {:channel, session.active_channel}
      true -> nil
    end
  end
end
