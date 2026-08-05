defmodule RetroHexChatWeb.Components.UI.System.HomePanel do
  @moduledoc """
  The node at a glance: what it is, how long it has run, what it is holding.

  This is the window a monitor opens on, so it answers the questions asked
  before any specific one: is this the build I think it is, has it restarted,
  is anything close to a ceiling, and where is the memory going. Everything
  needing a listing lives in another window.

  Composed entirely from the shared vocabulary — summary cards for the headline
  figures, usage meters for the bounded resources, the memory bar for the
  split — so this file arranges readings and owns no drawing of its own.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.MediaSession.SummaryCard
  import RetroHexChatWeb.Components.UI.System.{MemoryBar, UsageMeter}

  alias RetroHexChatWeb.Components.UI.Format
  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :info, :any, required: true, doc: "%SystemInfo.Runtime.Info{}"
  attr :usage, :any, required: true, doc: "%SystemInfo.Runtime.Snapshot{}"

  attr :versions, :list,
    default: [],
    doc: "Measured versions joined to their display name and icon"

  attr :target, :any, default: nil
  attr :on_refresh, :string, required: true
  attr :testid, :string, default: "system-home"

  @spec home_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def home_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-home"}
      class="adm-dialog retro-scrollbar flex h-full min-h-0 flex-col gap-retro-8 overflow-y-auto"
      data-testid={@testid}
    >
      <section class="shrink-0">
        <.section_heading icon={:icon_server} label={dgettext("dialogs", "System information")}>
          <.refresh_button target={@target} on_refresh={@on_refresh} />
        </.section_heading>

        <p class="bg-white p-2 font-mono text-[11px] leading-4 shadow-retro-sunken">
          {String.trim(@info.banner)}
        </p>

        <p class="mt-retro-2 flex min-w-0 items-center gap-1 text-[10px] text-muted-foreground">
          <Icons.icon_cpu class="h-3 w-3 shrink-0" />
          <span class="truncate">{@info.architecture}</span>
        </p>
      </section>

      <section class="grid shrink-0 grid-cols-2 gap-retro-6 sm:grid-cols-4">
        <.summary_card
          :for={version <- @versions}
          variant={:prominent}
          icon={version.icon}
          label={version.label}
          value={version.version || dgettext("dialogs", "not loaded")}
          testid={"system-home-version-#{version.app}"}
        />
      </section>

      <section class="grid shrink-0 grid-cols-3 gap-retro-6">
        <.summary_card
          variant={:prominent}
          icon={:icon_clock}
          label={dgettext("dialogs", "Uptime")}
          value={Format.duration_ms(@usage.uptime_ms)}
          testid="system-home-uptime"
        />
        <.summary_card
          variant={:prominent}
          icon={:icon_btn_down}
          label={dgettext("dialogs", "Total input")}
          value={Format.bytes(@usage.input_bytes)}
          testid="system-home-input"
        />
        <.summary_card
          variant={:prominent}
          icon={:icon_btn_up}
          label={dgettext("dialogs", "Total output")}
          value={Format.bytes(@usage.output_bytes)}
          testid="system-home-output"
        />
      </section>

      <section class="shrink-0">
        <.section_heading icon={:icon_cpu} label={dgettext("dialogs", "Run queues")} />

        <div class="grid grid-cols-3 gap-retro-6">
          <.summary_card
            variant={:prominent}
            icon={:icon_cpu}
            label={dgettext("dialogs", "Total")}
            value={Format.number(@usage.total_run_queue)}
            detail={dgettext("dialogs", "work waiting on a scheduler")}
            testid="system-home-runqueue-total"
          />
          <.summary_card
            variant={:prominent}
            icon={:icon_cpu}
            label={dgettext("dialogs", "CPU")}
            value={Format.number(@usage.cpu_run_queue)}
            testid="system-home-runqueue-cpu"
          />
          <.summary_card
            variant={:prominent}
            icon={:icon_plug}
            label={dgettext("dialogs", "IO")}
            value={Format.number(@usage.io_run_queue)}
            testid="system-home-runqueue-io"
          />
        </div>
      </section>

      <section class="shrink-0">
        <.section_heading icon={:icon_warning} label={dgettext("dialogs", "System limits")} />

        <div class="flex flex-col gap-retro-6">
          <.usage_meter
            icon={:icon_tag}
            label={dgettext("dialogs", "Atoms")}
            usage={@usage.atoms}
            hint={dgettext("dialogs", "Never reclaimed — exhausting the table ends the node")}
            testid="system-home-limit-atoms"
          />
          <.usage_meter
            icon={:icon_plug}
            label={dgettext("dialogs", "Ports")}
            usage={@usage.ports}
            hint={dgettext("dialogs", "Files, sockets and external programs")}
            testid="system-home-limit-ports"
          />
          <.usage_meter
            icon={:icon_cpu}
            label={dgettext("dialogs", "Processes")}
            usage={@usage.processes}
            testid="system-home-limit-processes"
          />
        </div>
      </section>

      <section class="shrink-0">
        <.memory_bar memory={@usage.memory} testid="system-home-memory" />
      </section>
    </div>
    """
  end

  attr :icon, :atom, required: true
  attr :label, :string, required: true
  slot :inner_block

  defp section_heading(assigns) do
    ~H"""
    <h3 class="mb-retro-4 flex min-w-0 items-center gap-1 text-xs font-bold">
      {apply(Icons, @icon, [%{class: "h-4 w-4 shrink-0"}])}
      <span class="min-w-0 flex-1 truncate">{@label}</span>
      {render_slot(@inner_block)}
    </h3>
    """
  end

  attr :target, :any, default: nil
  attr :on_refresh, :string, required: true

  defp refresh_button(assigns) do
    ~H"""
    <button
      type="button"
      class="shrink-0 p-retro-2 hover:bg-hover-bg"
      phx-click={@on_refresh}
      phx-target={@target}
      aria-label={dgettext("dialogs", "Refresh")}
      data-testid="system-home-refresh"
    >
      <Icons.icon_btn_refresh class="h-[14px] w-[14px]" />
    </button>
    """
  end
end
