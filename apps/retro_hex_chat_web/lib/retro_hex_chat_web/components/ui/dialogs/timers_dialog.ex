defmodule RetroHexChatWeb.Components.UI.TimersDialog do
  @moduledoc """
  Timer management dialog for session-scoped scheduled commands.

  Composed from the shared dialog, table, button, input, and checkbox primitives.
  Runtime scheduling stays in the LiveView process; this component only renders
  the current timer map and emits dialog events.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Table

  alias RetroHexChat.Chat.TimerManager
  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :show, :boolean, default: false
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
  attr :on_close, :any, default: nil, doc: "Dialog close event"

  @spec timers_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def timers_dialog(assigns) do
    assigns =
      assign(assigns,
        rows: timer_rows(assigns.timers),
        at_limit: map_size(assigns.timers) >= TimerManager.max_timers(),
        selected_active: Map.has_key?(assigns.timers, assigns.selected_timer),
        repeat_seconds_invalid:
          repeat_seconds_invalid?(assigns.draft_repeat, assigns.draft_seconds)
      )

    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_close} class="md:max-w-3xl">
      <.dialog_header id={@id} title={dgettext("dialogs", "Timers")} on_close={@on_close}>
        <:icon><Icons.icon_btn_timers class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body class="space-y-retro-8">
        <div class="max-h-[220px] overflow-y-auto retro-scrollbar shadow-retro-sunken">
          <.table>
            <.table_header>
              <.table_row>
                <.table_head class="w-[120px]">{dgettext("dialogs", "Name")}</.table_head>
                <.table_head class="w-[72px]">{dgettext("dialogs", "Every")}</.table_head>
                <.table_head class="w-[72px]">{dgettext("dialogs", "Repeat")}</.table_head>
                <.table_head class="w-[92px]">{dgettext("dialogs", "Next Fire")}</.table_head>
                <.table_head>{dgettext("dialogs", "Command")}</.table_head>
              </.table_row>
            </.table_header>
            <.table_body>
              <tr :if={@rows == []}>
                <td colspan="5" class="p-4 text-center text-muted-foreground text-xs">
                  {dgettext("dialogs", "No active timers. Click Add to schedule one.")}
                </td>
              </tr>
              <.table_row
                :for={row <- @rows}
                data-testid={"timer-row-#{row.name}"}
                class={
                  if(row.name == @selected_timer,
                    do: "bg-selection-bg text-selection-fg cursor-pointer",
                    else: "cursor-pointer"
                  )
                }
                phx-click={@on_select}
                phx-value-name={row.name}
              >
                <.table_cell class="font-mono text-xs">{row.name}</.table_cell>
                <.table_cell class="font-mono text-xs">{row.interval}s</.table_cell>
                <.table_cell class="text-xs">{repeat_label(row.type)}</.table_cell>
                <.table_cell class="font-mono text-xs">{row.next_fire}</.table_cell>
                <.table_cell class="font-mono text-xs truncate max-w-[260px]">
                  {row.command}
                </.table_cell>
              </.table_row>
            </.table_body>
          </.table>
        </div>

        <p :if={@at_limit} class="text-xs text-muted-foreground px-retro-2">
          {dgettext("dialogs", "Maximum 5 timers active. Stop one to add another.")}
        </p>

        <p class="text-[10px] text-muted-foreground px-retro-2">
          {dgettext("dialogs", "Timers are session-only and will be lost on disconnect.")}
        </p>

        <div class="flex gap-retro-4">
          <.button
            size="sm"
            variant="outline"
            phx-click={@on_add}
            disabled={@at_limit}
            data-testid="timers-dialog-add"
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
          >
            <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Edit")}
          </.button>
          <.button
            size="sm"
            variant="outline"
            phx-click={@on_stop}
            disabled={!@selected_active}
            data-testid="timers-dialog-stop"
          >
            <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Stop")}
          </.button>
        </div>

        <form
          :if={@editing}
          phx-change={@on_change}
          phx-submit={@on_save}
          data-testid="timers-edit-form"
          class="shadow-retro-field bg-white p-retro-8 space-y-retro-4"
        >
          <h3 class="font-bold text-xs mb-retro-4">
            {if @selected_active,
              do: dgettext("dialogs", "Edit Timer"),
              else: dgettext("dialogs", "Add Timer")}
          </h3>

          <div class="grid gap-retro-4 md:grid-cols-[160px_120px_1fr]">
            <div>
              <label class="text-xs font-bold block mb-retro-2">
                {dgettext("dialogs", "Name")}
              </label>
              <.input
                type="text"
                name="name"
                value={@draft_name}
                placeholder={dgettext("dialogs", "e.g. remind")}
                data-testid="timer-name-input"
                class="w-full text-xs h-7"
                maxlength="30"
                disabled={@selected_active}
              />
            </div>

            <div>
              <label class="text-xs font-bold block mb-retro-2">
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
                  "w-full text-xs h-7",
                  @repeat_seconds_invalid && "!border-destructive"
                ]}
              />
            </div>

            <div>
              <label class="text-xs font-bold block mb-retro-2">
                {dgettext("dialogs", "Command")}
              </label>
              <.input
                type="text"
                name="command"
                value={@draft_command}
                placeholder={dgettext("dialogs", "/me standup in 30 minutes")}
                data-testid="timer-command-input"
                class="w-full text-xs h-7"
                maxlength="500"
              />
            </div>
          </div>

          <label class="inline-flex items-center gap-retro-4 text-xs">
            <.checkbox name="repeat" value={@draft_repeat} data-testid="timer-repeat-checkbox" />
            {dgettext("dialogs", "Repeating timer")}
          </label>

          <p :if={@repeat_seconds_invalid} class="text-xs text-destructive">
            {repeat_min_message()}
          </p>

          <p :if={@error_message} data-testid="timers-dialog-error" class="text-xs text-destructive">
            {@error_message}
          </p>

          <div class="flex gap-retro-4 pt-retro-4">
            <.button type="submit" size="sm" variant="default">
              <:icon><Icons.icon_btn_save class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Save")}
            </.button>
            <.button type="button" size="sm" variant="outline" phx-click={@on_cancel_edit}>
              <:icon><Icons.icon_btn_cancel class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="outline" phx-click={@on_close || hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          {dgettext("dialogs", "Close")}
        </.button>
      </.dialog_footer>
    </.dialog>
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
end
