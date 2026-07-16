defmodule RetroHexChatWeb.Components.UI.TimersDialog do
  @moduledoc """
  Timer management panel for session-scoped scheduled commands — the body of
  the Timers desktop window.

  Composed from the shared button, input, textarea, and checkbox primitives.
  Runtime scheduling stays in the LiveView process; this component only renders
  the current timer map and emits events.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Textarea

  alias RetroHexChat.Chat.TimerManager
  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :timers, :map, default: %{}, doc: "Map of timer name to timer runtime info"
  attr :selected_timer, :string, default: nil, doc: "Name of the selected active timer"
  attr :editing, :boolean, default: false, doc: "True when Add/Edit form is visible"
  attr :draft_name, :string, default: "", doc: "Draft timer name"
  attr :draft_repeat, :boolean, default: false, doc: "Draft repeat toggle"
  attr :draft_seconds, :string, default: "", doc: "Draft interval in seconds"
  attr :draft_command, :string, default: "", doc: "Draft command"
  attr :error_message, :string, default: nil, doc: "Inline form error"
  attr :on_select, :any, default: nil, doc: "Row select event"
  attr :on_add, :any, default: nil, doc: "Add button event"
  attr :on_edit, :any, default: nil, doc: "Edit button event"
  attr :on_stop, :any, default: nil, doc: "Stop button event"
  attr :on_change, :any, default: nil, doc: "Form change event"
  attr :on_save, :any, default: nil, doc: "Form submit event"
  attr :on_cancel_edit, :any, default: nil, doc: "Cancel edit event"
  attr :on_close, :any, default: nil, doc: "Close/OK event"

  @spec timers_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def timers_panel(assigns) do
    assigns =
      assign(assigns,
        rows: timer_rows(assigns.timers),
        at_limit: map_size(assigns.timers) >= TimerManager.max_timers(),
        selected_active: Map.has_key?(assigns.timers, assigns.selected_timer),
        repeat_seconds_invalid:
          repeat_seconds_invalid?(assigns.draft_repeat, assigns.draft_seconds)
      )

    ~H"""
    <div id={"#{@id}-panel-root"} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="timers-panel"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "##{@id}-content")}
          class="tm-dialog flex h-full min-h-0 flex-col gap-retro-8"
        >
          <div class={
            classes([
              "tm-editor min-h-0 flex-1",
              @editing && "tm-editor--editing"
            ])
          }>
            <div class="tm-list-pane min-h-0">
              <div class="tm-timer-list overflow-y-auto retro-scrollbar">
                <div :if={@rows == []} class="tm-empty-state text-center text-muted-foreground">
                  {dgettext("dialogs", "No active timers. Click Add to schedule one.")}
                </div>

                <button
                  :for={row <- @rows}
                  type="button"
                  data-testid={"timer-row-#{row.name}"}
                  aria-pressed={row.name == @selected_timer}
                  aria-label={row.name}
                  class={timer_entry_class(row.name == @selected_timer)}
                  phx-click={@on_select}
                  phx-value-name={row.name}
                >
                  <span class="tm-timer-name">{row.name}</span>
                  <span class="tm-timer-meta">
                    <span>
                      <span class="tm-timer-meta-label">{dgettext("dialogs", "Every")}</span>
                      {row.interval}s
                    </span>
                    <span>
                      <span class="tm-timer-meta-label">{dgettext("dialogs", "Repeat")}</span>
                      {repeat_label(row.type)}
                    </span>
                    <span>
                      <span class="tm-timer-meta-label">{dgettext("dialogs", "Next")}</span>
                      {row.next_fire}
                    </span>
                  </span>
                  <code class="tm-timer-command">{row.command}</code>
                </button>
              </div>

              <p :if={@at_limit} class="tm-note text-xs text-muted-foreground">
                {dgettext("dialogs", "Maximum 5 timers active. Stop one to add another.")}
              </p>

              <p class="tm-note text-[10px] text-muted-foreground">
                {dgettext("dialogs", "Timers are session-only and will be lost on disconnect.")}
              </p>

              <div class="tm-action-row flex gap-retro-4">
                <.button
                  size="sm"
                  variant="outline"
                  phx-click={@on_add}
                  disabled={@at_limit}
                  data-testid="timers-dialog-add"
                  class="tm-action-button"
                >
                  <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Add")}
                </.button>
                <.button
                  size="sm"
                  variant="outline"
                  phx-click={@on_edit}
                  disabled={!@selected_active}
                  data-testid="timers-dialog-edit"
                  class="tm-action-button"
                >
                  <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Edit")}
                </.button>
                <.button
                  size="sm"
                  variant="outline"
                  phx-click={@on_stop}
                  phx-value-selected={@selected_timer}
                  disabled={!@selected_active}
                  data-testid="timers-dialog-stop"
                  class="tm-action-button"
                >
                  <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Stop")}
                </.button>
              </div>
            </div>

            <form
              :if={@editing}
              phx-change={@on_change}
              phx-submit={@on_save}
              data-testid="timers-edit-form"
              class="tm-edit-form shadow-retro-field bg-white p-retro-8"
            >
              <input :if={@selected_timer} type="hidden" name="selected" value={@selected_timer} />
              <h3 class="font-bold text-xs">
                {if @selected_active,
                  do: dgettext("dialogs", "Edit Timer"),
                  else: dgettext("dialogs", "Add Timer")}
              </h3>

              <div class="tm-form-fields">
                <div class="tm-field">
                  <label class="tm-form-label">
                    {dgettext("dialogs", "Name")}
                  </label>
                  <.input
                    type="text"
                    name="name"
                    value={@draft_name}
                    placeholder={dgettext("dialogs", "e.g. remind")}
                    data-testid="timer-name-input"
                    class="tm-input w-full text-xs h-7"
                    maxlength="30"
                    disabled={@selected_active}
                  />
                </div>

                <div class="tm-field">
                  <label class="tm-form-label">
                    {seconds_label(@draft_repeat)}
                  </label>
                  <.input
                    type="number"
                    name="seconds"
                    value={@draft_seconds}
                    min={TimerManager.min_once_interval()}
                    max={TimerManager.max_interval()}
                    step="1"
                    data-testid="timer-seconds-input"
                    class={[
                      "tm-input w-full text-xs h-7",
                      @repeat_seconds_invalid && "!border-destructive"
                    ]}
                  />
                </div>

                <div class="tm-field">
                  <label class="tm-form-label">
                    {dgettext("dialogs", "Command")}
                  </label>
                  <.textarea
                    name="command"
                    value={@draft_command}
                    placeholder={dgettext("dialogs", "/me standup in 30 minutes")}
                    data-testid="timer-command-input"
                    class="tm-command-input tm-input w-full resize-none text-xs"
                    maxlength="500"
                    rows="3"
                  />
                </div>
              </div>

              <label class="tm-repeat-row inline-flex items-center gap-retro-4 text-xs">
                <.checkbox name="repeat" value={@draft_repeat} data-testid="timer-repeat-checkbox" />
                {dgettext("dialogs", "Repeating timer")}
              </label>

              <p :if={@repeat_seconds_invalid} class="tm-error text-xs text-destructive">
                {repeat_min_message()}
              </p>

              <p
                :if={@error_message}
                data-testid="timers-dialog-error"
                class="tm-error text-xs text-destructive"
              >
                {@error_message}
              </p>

              <div class="tm-form-actions flex gap-retro-4 pt-retro-4">
                <.button type="submit" size="sm" variant="default" class="tm-action-button">
                  <:icon><Icons.icon_btn_save class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Save")}
                </.button>
                <.button
                  type="button"
                  size="sm"
                  variant="outline"
                  phx-click={@on_cancel_edit}
                  class="tm-action-button"
                >
                  <:icon><Icons.icon_btn_cancel class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Cancel")}
                </.button>
              </div>
            </form>
          </div>

          <div :if={@on_close} class="tm-dialog-footer flex justify-end">
            <.button
              type="button"
              size="sm"
              phx-click={@on_close}
              phx-target={@target}
              class="tm-action-button"
            >
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
          </div>
        </div>
      </.focus_wrap>
    </div>
    """
  end

  defp timer_rows(timers) do
    timers
    |> Enum.sort_by(fn {name, _info} -> name end)
    |> Enum.map(fn {name, info} ->
      %{
        name: name,
        type: timer_value(info, :type, :once),
        interval: timer_value(info, :interval, 0),
        command: timer_value(info, :command, ""),
        next_fire: next_fire_label(timer_value(info, :ref, nil))
      }
    end)
  end

  defp timer_value(info, key, default) do
    Map.get(info, key, Map.get(info, Atom.to_string(key), default))
  end

  defp next_fire_label(nil), do: "--"

  defp next_fire_label(ref) do
    case Process.read_timer(ref) do
      milliseconds when is_integer(milliseconds) ->
        milliseconds
        |> div(1_000)
        |> max(0)
        |> format_duration()

      _ ->
        "--"
    end
  end

  defp format_duration(seconds) when seconds >= 3_600 do
    hours = div(seconds, 3_600)
    minutes = seconds |> rem(3_600) |> div(60)
    secs = rem(seconds, 60)
    "#{hours}:#{pad2(minutes)}:#{pad2(secs)}"
  end

  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{pad2(secs)}"
  end

  defp pad2(value), do: value |> Integer.to_string() |> String.pad_leading(2, "0")

  defp repeat_label(:repeat), do: dgettext("dialogs", "yes")
  defp repeat_label("repeat"), do: dgettext("dialogs", "yes")
  defp repeat_label(_), do: dgettext("dialogs", "no")

  defp seconds_label(true), do: dgettext("dialogs", "Seconds (min 10)")
  defp seconds_label(_), do: dgettext("dialogs", "Seconds")

  defp repeat_seconds_invalid?(true, seconds) do
    case Integer.parse(to_string(seconds)) do
      {value, ""} -> value < TimerManager.min_repeat_interval()
      _ -> false
    end
  end

  defp repeat_seconds_invalid?(_, _seconds), do: false

  defp repeat_min_message, do: dgettext("dialogs", "min 10s for repeating timers")

  defp timer_entry_class(true), do: "tm-timer-entry bg-selection-bg text-selection-fg"
  defp timer_entry_class(false), do: "tm-timer-entry"
end
