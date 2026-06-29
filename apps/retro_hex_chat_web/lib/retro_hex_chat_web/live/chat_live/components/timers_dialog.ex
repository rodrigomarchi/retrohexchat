defmodule RetroHexChatWeb.ChatLive.Components.TimersDialog do
  @moduledoc """
  Stateful LiveComponent for the Timers dialog — the inline-edit-list
  pattern, but NOT Escape-managed, so the component owns its visibility (`show`)
  outright. The running timers map (`timers`, i.e. the parent's `user_timers`
  runtime state) is passed through.

  Owned UI/draft state: `show`, `selected`, `editing`, `draft_name`,
  `draft_repeat`, `draft_seconds`, `draft_command`, `error`. Pure-UI events
  (open/close/select/add/edit/change/cancel) are component-local; the mutating
  save/stop bubble to the parent as plain string events (they schedule via
  `UiActions.Scripting`). The selected timer reaches the parent through the form's
  hidden `selected` input (save) and the Stop button's `phx-value-selected` (stop)
  rather than `JS.push(value:)` — the latter is NOT dispatched by `render_submit`
  under LiveViewTest. The parent reflects results back via `send_update/2`:

  - `{:open}`           — show the dialog (draft preserved; cleared on close)
  - `{:saved, name}`    — timer created/updated; select it, leave edit mode
  - `:stopped`          — timer stopped; clear selection
  - `{:error, message}` — inline error (keeps the current draft)
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.TimersDialog

  alias RetroHexChat.Chat.TimerManager

  @id "timers-dialog"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket, [{:id, @id}, {:show, false}, {:timers, %{}}, {:selected, nil} | blank_draft()])}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:open}}, socket), do: {:ok, assign(socket, show: true, error: nil)}

  def update(%{action: {:saved, name}}, socket) do
    {:ok, assign(socket, [{:selected, name} | blank_draft()])}
  end

  def update(%{action: :stopped}, socket) do
    {:ok, assign(socket, [{:selected, nil} | blank_draft()])}
  end

  def update(%{action: {:error, message}}, socket), do: {:ok, assign(socket, error: message)}

  def update(assigns, socket) do
    {:ok, assign(socket, timers: Map.get(assigns, :timers, socket.assigns.timers))}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("timers_close", _params, socket) do
    {:noreply, assign(socket, [{:show, false}, {:selected, nil} | blank_draft()])}
  end

  def handle_event("timers_select", %{"name" => name}, socket) do
    {:noreply, assign(socket, selected: name, editing: false, error: nil)}
  end

  def handle_event("timers_dialog_add", _params, socket) do
    {:noreply, assign(socket, [{:selected, nil}, {:editing, true} | draft_fields()])}
  end

  def handle_event("timers_dialog_edit", _params, socket) do
    case Map.get(socket.assigns.timers, socket.assigns.selected) do
      nil ->
        {:noreply, assign(socket, error: dgettext("chat", "Timer not found"))}

      timer ->
        {:noreply,
         assign(socket,
           editing: true,
           draft_name: socket.assigns.selected,
           draft_repeat: timer.type == :repeat,
           draft_seconds: Integer.to_string(timer.interval),
           draft_command: timer.command,
           error: nil
         )}
    end
  end

  def handle_event("timers_dialog_change", params, socket) do
    draft = draft_from_params(params, socket.assigns.selected)

    {:noreply,
     assign(socket,
       draft_name: draft.name,
       draft_repeat: draft.repeat?,
       draft_seconds: draft.seconds,
       draft_command: draft.command,
       error: repeat_interval_error(draft.repeat?, draft.seconds)
     )}
  end

  def handle_event("timers_dialog_cancel_edit", _params, socket) do
    {:noreply, assign(socket, [{:editing, false} | draft_fields()])}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.timers_dialog
        id={@id}
        show={@show}
        timers={@timers}
        selected_timer={@selected}
        editing={@editing}
        draft_name={@draft_name}
        draft_repeat={@draft_repeat}
        draft_seconds={@draft_seconds}
        draft_command={@draft_command}
        error_message={@error}
        on_select={JS.push("timers_select", target: @myself)}
        on_add={JS.push("timers_dialog_add", target: @myself)}
        on_edit={JS.push("timers_dialog_edit", target: @myself)}
        on_stop="timers_dialog_stop"
        on_change={JS.push("timers_dialog_change", target: @myself)}
        on_save="timers_dialog_save"
        on_cancel_edit={JS.push("timers_dialog_cancel_edit", target: @myself)}
        on_close={JS.push("timers_close", target: @myself)}
      />
    </div>
    """
  end

  # Empty draft + clears editing/error (used on saved/stopped/close).
  @spec blank_draft() :: keyword()
  defp blank_draft, do: [{:editing, false}, {:error, nil} | draft_fields()]

  # Just the four draft inputs reset to defaults.
  @spec draft_fields() :: keyword()
  defp draft_fields do
    [draft_name: "", draft_repeat: false, draft_seconds: "", draft_command: ""]
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

  @spec repeat_interval_error(boolean(), String.t()) :: String.t() | nil
  defp repeat_interval_error(true, seconds) do
    case Integer.parse(seconds) do
      {value, ""} ->
        if value < TimerManager.min_repeat_interval(), do: repeat_min_message(), else: nil

      _ ->
        nil
    end
  end

  defp repeat_interval_error(_repeat?, _seconds), do: nil

  @spec repeat_min_message() :: String.t()
  defp repeat_min_message, do: dgettext("chat", "min 10s for repeating timers")

  @spec truthy?(term()) :: boolean()
  defp truthy?(true), do: true
  defp truthy?("true"), do: true
  defp truthy?("on"), do: true
  defp truthy?(_), do: false
end
