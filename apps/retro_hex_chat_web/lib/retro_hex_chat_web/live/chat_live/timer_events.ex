defmodule RetroHexChatWeb.ChatLive.TimerEvents do
  @moduledoc """
  Handles the Timers dialog events that need the LiveView.

  The dialog's UI/draft state (select/add/edit/change/cancel) lives in the
  `Components.TimersDialog` LiveComponent, mounted inside a server-managed
  desktop window. This module opens the window (mounting the island) and
  handles the mutating save/stop, which schedule through `UiActions.Scripting`
  and reflect results back to the component.

  Attached as `attach_hook(:timer_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.LiveView, only: [send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Chat.TimerManager
  alias RetroHexChatWeb.ChatLive.Components.TimersDialog
  alias RetroHexChatWeb.ChatLive.UiActions.Scripting
  alias RetroHexChatWeb.ChatLive.Windows

  @type event_result ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: event_result()
  def handle_event("open_timers_dialog", _params, socket) do
    {:halt, Windows.open(socket, "timers")}
  end

  def handle_event("timers_dialog_save", params, socket) do
    draft = draft_from_params(params, params["selected"])
    type = if draft.repeat?, do: :repeat, else: :once

    with {:ok, seconds} <- parse_seconds(draft.seconds),
         :ok <- validate_repeat_interval(type, seconds) do
      case Scripting.create_timer(socket, draft.name, type, seconds, draft.command) do
        {:ok, socket} ->
          send_update(TimersDialog, id: TimersDialog.id(), action: {:saved, draft.name})
          {:halt, socket}

        {:error, socket, message} ->
          timer_error(socket, message)
      end
    else
      {:error, message} -> timer_error(socket, message)
    end
  end

  def handle_event("timers_dialog_stop", params, socket) do
    case params["selected"] do
      nil ->
        {:halt, socket}

      selected ->
        case Scripting.stop_timer(socket, selected) do
          {:ok, socket} ->
            send_update(TimersDialog, id: TimersDialog.id(), action: :stopped)
            {:halt, socket}

          {:error, socket, message} ->
            timer_error(socket, message)
        end
    end
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @spec timer_error(Phoenix.LiveView.Socket.t(), String.t()) :: event_result()
  defp timer_error(socket, message) do
    send_update(TimersDialog, id: TimersDialog.id(), action: {:error, message})
    {:halt, socket}
  end

  @spec draft_from_params(map(), String.t() | nil) :: map()
  defp draft_from_params(params, selected) do
    %{
      name: selected || String.trim(Map.get(params, "name", "")),
      repeat?: truthy?(Map.get(params, "repeat", false)),
      seconds: String.trim(Map.get(params, "seconds", "")),
      command: String.trim(Map.get(params, "command", ""))
    }
  end

  @spec parse_seconds(String.t()) :: {:ok, integer()} | {:error, String.t()}
  defp parse_seconds(seconds) do
    case Integer.parse(seconds) do
      {value, ""} -> {:ok, value}
      _ -> {:error, dgettext("chat", "Seconds must be a number.")}
    end
  end

  @spec validate_repeat_interval(:repeat | :once, integer()) :: :ok | {:error, String.t()}
  defp validate_repeat_interval(:repeat, seconds) do
    if seconds < TimerManager.min_repeat_interval() do
      {:error, dgettext("chat", "min 10s for repeating timers")}
    else
      :ok
    end
  end

  defp validate_repeat_interval(_type, _seconds), do: :ok

  @spec truthy?(term()) :: boolean()
  defp truthy?(true), do: true
  defp truthy?("true"), do: true
  defp truthy?("on"), do: true
  defp truthy?(_), do: false
end
