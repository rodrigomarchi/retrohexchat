defmodule RetroHexChatWeb.Components.UI.System.LogPanel do
  @moduledoc """
  A live tail of what the node is logging.

  Read like a terminal, so it looks like one: monospaced, light on black, level
  carried by colour rather than by a column. The newest line is at the bottom,
  which is where a tail is read from.

  Streaming is a toggle rather than a default. A window left streaming on a
  busy server is a permanent broadcast to a browser nobody is watching, and
  making that a deliberate act keeps it from happening by accident.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :entries, :list, default: [], doc: "Newest last"
  attr :streaming, :boolean, default: false
  attr :level, :atom, default: :info
  attr :levels, :list, default: [:debug, :info, :warning, :error]
  attr :dropped, :integer, default: 0

  attr :primary_level, :atom,
    default: :debug,
    doc: "What the node filters at before any handler runs"

  attr :reachable, :boolean,
    default: true,
    doc: "False when the chosen level is below what the node will emit at all"

  attr :target, :any, default: nil
  attr :on_toggle, :string, required: true
  attr :on_clear, :string, required: true
  attr :on_level, :string, required: true
  attr :testid, :string, default: "system-log"

  @spec log_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def log_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-log"}
      class="adm-dialog flex h-full min-h-0 flex-col gap-retro-8"
      data-testid={@testid}
    >
      <h3 class="flex min-w-0 shrink-0 items-center gap-1 text-xs font-bold">
        <Icons.icon_terminal class="h-4 w-4 shrink-0" />
        <span class="min-w-0 flex-1 truncate">{dgettext("dialogs", "Live log")}</span>
        <span class="shrink-0 font-normal text-muted-foreground">
          {dgettext("dialogs", "%{count} lines", count: length(@entries))}
        </span>
      </h3>

      <form
        id={"#{@id}-controls"}
        class="flex shrink-0 items-end gap-retro-6"
        phx-change={@on_level}
        phx-target={@target}
      >
        <div class="w-[110px] shrink-0">
          <label for={"#{@id}-level"} class="mb-retro-2 block text-xs font-bold">
            {dgettext("dialogs", "Level")}
          </label>
          <select
            id={"#{@id}-level"}
            name="level"
            class="w-full bg-white px-retro-4 py-retro-2 text-sm shadow-retro-sunken"
          >
            <option :for={level <- @levels} value={level} selected={level == @level}>
              {level}
            </option>
          </select>
        </div>

        <.button
          type="button"
          size="sm"
          variant="outline"
          phx-click={@on_toggle}
          phx-target={@target}
          data-testid="system-log-toggle"
        >
          <:icon>
            <Icons.icon_btn_disconnect :if={@streaming} class="h-[14px] w-[14px]" />
            <Icons.icon_btn_connect_lightning :if={not @streaming} class="h-[14px] w-[14px]" />
          </:icon>
          {if @streaming,
            do: dgettext("dialogs", "Stop"),
            else: dgettext("dialogs", "Stream")}
        </.button>

        <.button
          type="button"
          size="sm"
          variant="outline"
          phx-click={@on_clear}
          phx-target={@target}
          data-testid="system-log-clear"
        >
          <:icon><Icons.icon_btn_trash class="h-[14px] w-[14px]" /></:icon>
          {dgettext("dialogs", "Clear")}
        </.button>
      </form>

      <p
        :if={not @reachable}
        class="shrink-0 bg-warning-bg p-retro-6 text-xs shadow-retro-sunken"
        data-testid="system-log-unreachable"
      >
        {dgettext(
          "dialogs",
          "This node logs at %{primary} and drops anything below it before a window can see it, so nothing at %{selected} will ever appear here.",
          primary: @primary_level,
          selected: @level
        )}
      </p>

      <div
        id={"#{@id}-stream"}
        class="retro-scrollbar min-h-0 flex-1 overflow-auto bg-black p-retro-6 font-mono text-xs shadow-retro-sunken"
        data-testid="system-log-stream"
      >
        <p :if={@entries == []} class="text-gray-400">
          {if @streaming,
            do: dgettext("dialogs", "Waiting for the server to log something…"),
            else: dgettext("dialogs", "Press Stream to tail the server log.")}
        </p>

        <p
          :if={@dropped > 0}
          class="text-gray-400"
          data-testid="system-log-dropped"
        >
          {dgettext("dialogs", "… %{count} earlier lines dropped", count: @dropped)}
        </p>

        <p :for={entry <- @entries} class="whitespace-pre-wrap break-words">
          <span class="text-gray-400">{time(entry.at)}</span>
          <span class={level_class(entry.level)}>[{entry.level}]</span>
          <span class="text-gray-100">{entry.message}</span>
        </p>
      </div>
    </div>
    """
  end

  defp time(%DateTime{} = at) do
    at |> DateTime.to_time() |> Time.truncate(:second) |> Time.to_string()
  end

  defp level_class(:error), do: "text-red-400 font-bold"
  defp level_class(:warning), do: "text-yellow-400"
  defp level_class(:debug), do: "text-gray-500"
  defp level_class(_info), do: "text-green-400"
end
