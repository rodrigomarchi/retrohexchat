defmodule RetroHexChatWeb.ChatLive.TimerEvents do
  @moduledoc """
  Handle events for the Timers dialog.

  Attached as `attach_hook(:timer_events, :handle_event, ...)` in ChatLive.mount/3.
  Dialog events only manage UI state and delegate timer scheduling to
  `UiActions.Scripting`.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Chat.TimerManager
  alias RetroHexChatWeb.ChatLive.UiActions.Scripting

  @type event_result ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: event_result()
  def handle_event("open_timers_dialog", _params, socket) do
    {:halt, assign(socket, show_timers_dialog: true, timers_dialog_error: nil)}
  end

  def handle_event("close_timers_dialog", _params, socket) do
    {:halt, reset_timers_dialog(socket, show_timers_dialog: false, timers_dialog_selected: nil)}
  end

  def handle_event("timers_select", %{"name" => name}, socket) do
    {:halt,
     assign(socket,
       timers_dialog_selected: name,
       timers_dialog_editing: false,
       timers_dialog_error: nil
     )}
  end

  def handle_event("timers_dialog_add", _params, socket) do
    {:halt,
     assign(socket,
       timers_dialog_selected: nil,
       timers_dialog_editing: true,
       timers_dialog_draft_name: "",
       timers_dialog_draft_repeat: false,
       timers_dialog_draft_seconds: "",
       timers_dialog_draft_command: "",
       timers_dialog_error: nil
     )}
  end

  def handle_event("timers_dialog_edit", _params, socket) do
    selected = socket.assigns.timers_dialog_selected

    case Map.get(socket.assigns.user_timers, selected) do
      nil ->
        {:halt, assign(socket, timers_dialog_error: dgettext("chat", "Timer not found"))}

      timer ->
        {:halt,
         assign(socket,
           timers_dialog_editing: true,
           timers_dialog_draft_name: selected,
           timers_dialog_draft_repeat: timer.type == :repeat,
           timers_dialog_draft_seconds: Integer.to_string(timer.interval),
           timers_dialog_draft_command: timer.command,
           timers_dialog_error: nil
         )}
    end
  end

  def handle_event("timers_dialog_change", params, socket) do
    draft = draft_from_params(params, socket.assigns.timers_dialog_selected)

    {:halt,
     assign(socket,
       timers_dialog_draft_name: draft.name,
       timers_dialog_draft_repeat: draft.repeat?,
       timers_dialog_draft_seconds: draft.seconds,
       timers_dialog_draft_command: draft.command,
       timers_dialog_error: repeat_interval_error(draft.repeat?, draft.seconds)
     )}
  end

  def handle_event("timers_dialog_save", params, socket) do
    draft = draft_from_params(params, socket.assigns.timers_dialog_selected)
    type = if draft.repeat?, do: :repeat, else: :once

    with {:ok, seconds} <- parse_seconds(draft.seconds),
         :ok <- validate_repeat_interval(type, seconds) do
      case Scripting.create_timer(socket, draft.name, type, seconds, draft.command) do
        {:ok, socket} ->
          {:halt,
           assign(socket,
             timers_dialog_selected: draft.name,
             timers_dialog_editing: false,
             timers_dialog_draft_name: "",
             timers_dialog_draft_repeat: false,
             timers_dialog_draft_seconds: "",
             timers_dialog_draft_command: "",
             timers_dialog_error: nil
           )}

        {:error, socket, message} ->
          {:halt, assign_draft_error(socket, draft, message)}
      end
    else
      {:error, message} ->
        {:halt, assign_draft_error(socket, draft, message)}
    end
  end

  def handle_event("timers_dialog_stop", _params, socket) do
    selected = socket.assigns.timers_dialog_selected

    if selected do
      case Scripting.stop_timer(socket, selected) do
        {:ok, socket} ->
          {:halt,
           assign(socket,
             timers_dialog_selected: nil,
             timers_dialog_editing: false,
             timers_dialog_draft_name: "",
             timers_dialog_draft_repeat: false,
             timers_dialog_draft_seconds: "",
             timers_dialog_draft_command: "",
             timers_dialog_error: nil
           )}

        {:error, socket, message} ->
          {:halt, assign(socket, timers_dialog_error: message)}
      end
    else
      {:halt, socket}
    end
  end

  def handle_event("timers_dialog_cancel_edit", _params, socket) do
    {:halt,
     assign(socket,
       timers_dialog_editing: false,
       timers_dialog_draft_name: "",
       timers_dialog_draft_repeat: false,
       timers_dialog_draft_seconds: "",
       timers_dialog_draft_command: "",
       timers_dialog_error: nil
     )}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  defp reset_timers_dialog(socket, overrides) do
    defaults = [
      timers_dialog_editing: false,
      timers_dialog_draft_name: "",
      timers_dialog_draft_repeat: false,
      timers_dialog_draft_seconds: "",
      timers_dialog_draft_command: "",
      timers_dialog_error: nil
    ]

    assign(socket, Keyword.merge(defaults, overrides))
  end

  defp draft_from_params(params, selected) do
    %{
      name: selected || String.trim(Map.get(params, "name", "")),
      repeat?: truthy?(Map.get(params, "repeat", false)),
      seconds: String.trim(Map.get(params, "seconds", "")),
      command: String.trim(Map.get(params, "command", ""))
    }
  end

  defp assign_draft_error(socket, draft, message) do
    assign(socket,
      timers_dialog_draft_name: draft.name,
      timers_dialog_draft_repeat: draft.repeat?,
      timers_dialog_draft_seconds: draft.seconds,
      timers_dialog_draft_command: draft.command,
      timers_dialog_error: message
    )
  end

  defp parse_seconds(seconds) do
    case Integer.parse(seconds) do
      {value, ""} -> {:ok, value}
      _ -> {:error, dgettext("chat", "Seconds must be a number.")}
    end
  end

  defp validate_repeat_interval(:repeat, seconds) do
    if seconds < TimerManager.min_repeat_interval() do
      {:error, repeat_min_message()}
    else
      :ok
    end
  end

  defp validate_repeat_interval(_type, _seconds), do: :ok

  defp repeat_interval_error(true, seconds) do
    case Integer.parse(seconds) do
      {value, ""} -> repeat_interval_error_for_value(value)
      _ -> nil
    end
  end

  defp repeat_interval_error(_repeat?, _seconds), do: nil

  defp repeat_interval_error_for_value(value) do
    if value < TimerManager.min_repeat_interval() do
      repeat_min_message()
    else
      nil
    end
  end

  defp repeat_min_message, do: dgettext("chat", "min 10s for repeating timers")

  defp truthy?(true), do: true
  defp truthy?("true"), do: true
  defp truthy?("on"), do: true
  defp truthy?(_), do: false
end
