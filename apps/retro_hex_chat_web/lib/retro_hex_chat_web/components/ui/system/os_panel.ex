defmodule RetroHexChatWeb.Components.UI.System.OsPanel do
  @moduledoc """
  The machine underneath the VM, as far as it will say.

  Every other runtime window reports the emulator's own accounting, which is
  blind to its neighbours: a node can look healthy while the host it shares is
  out of memory or pinned by another tenant. This is the outside view.

  Nothing here is guaranteed. `:os_mon` reports different subsets per platform,
  so each reading renders as unavailable rather than as a zero — a gauge
  sitting at 0% and a gauge that cannot be read are different facts, and
  showing them the same way would be a lie about the host.

  Load average is drawn against the processor count, because the number alone
  says nothing: 4 is idle on a 16-core box and desperate on a single core.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.MediaSession.SummaryCard
  import RetroHexChatWeb.Components.UI.Progress

  alias RetroHexChatWeb.Components.UI.Format
  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :os, :any, required: true, doc: "%SystemInfo.OS{}"
  attr :available, :boolean, default: true, doc: "Whether :os_mon answers at all"
  attr :target, :any, default: nil
  attr :on_refresh, :string, required: true
  attr :testid, :string, default: "system-os"

  @spec os_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def os_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-os"}
      class="adm-dialog retro-scrollbar flex h-full min-h-0 flex-col gap-retro-8 overflow-y-auto"
      data-testid={@testid}
    >
      <h3 class="flex min-w-0 shrink-0 items-center gap-1 text-xs font-bold">
        <Icons.icon_operating_system class="h-4 w-4 shrink-0" />
        <span class="min-w-0 flex-1 truncate">{dgettext("dialogs", "Host")}</span>
        <button
          type="button"
          class="shrink-0 p-retro-2 hover:bg-hover-bg"
          phx-click={@on_refresh}
          phx-target={@target}
          aria-label={dgettext("dialogs", "Refresh")}
          data-testid="system-os-refresh"
        >
          <Icons.icon_btn_refresh class="h-[14px] w-[14px]" />
        </button>
      </h3>

      <p
        :if={not @available}
        class="shrink-0 bg-white p-2 text-xs shadow-retro-sunken"
        data-testid="system-os-unavailable"
      >
        {dgettext(
          "dialogs",
          "The :os_mon application is not running on this node, so the host cannot be read."
        )}
      </p>

      <section class="grid shrink-0 grid-cols-2 gap-retro-6 sm:grid-cols-4">
        <.summary_card
          variant={:prominent}
          icon={:icon_cpu}
          label={dgettext("dialogs", "Processors")}
          value={reading(@os.logical_processors, &Format.number/1)}
          testid="system-os-processors"
        />
        <.summary_card
          variant={:prominent}
          icon={:icon_status_signal}
          label={dgettext("dialogs", "Load 1m")}
          value={reading(@os.cpu_avg1, &load/1)}
          detail={load_detail(@os)}
          testid="system-os-load1"
        />
        <.summary_card
          variant={:prominent}
          icon={:icon_status_signal}
          label={dgettext("dialogs", "Load 5m")}
          value={reading(@os.cpu_avg5, &load/1)}
          testid="system-os-load5"
        />
        <.summary_card
          variant={:prominent}
          icon={:icon_status_signal}
          label={dgettext("dialogs", "Load 15m")}
          value={reading(@os.cpu_avg15, &load/1)}
          testid="system-os-load15"
        />
      </section>

      <.host_gauge
        :if={@os.cpu_util}
        icon={:icon_cpu}
        label={dgettext("dialogs", "CPU in use")}
        percent={@os.cpu_util}
        detail={dgettext("dialogs", "Measured since the previous reading")}
        testid="system-os-cpu-util"
      />

      <.host_gauge
        :if={@os.total_memory && @os.used_memory}
        icon={:icon_memory}
        label={dgettext("dialogs", "Host memory")}
        percent={@os.used_memory / @os.total_memory * 100}
        detail={
          dgettext("dialogs", "%{used} of %{total} — %{free} free",
            used: Format.bytes(@os.used_memory),
            total: Format.bytes(@os.total_memory),
            free: Format.bytes(@os.free_memory)
          )
        }
        testid="system-os-memory"
      />

      <section :if={@os.disks != []} class="shrink-0">
        <h4 class="mb-retro-4 flex min-w-0 items-center gap-1 text-xs font-bold">
          <Icons.icon_database class="h-4 w-4 shrink-0" />
          <span class="truncate">{dgettext("dialogs", "Disks")}</span>
        </h4>

        <div class="flex flex-col gap-retro-6">
          <.host_gauge
            :for={disk <- @os.disks}
            icon={:icon_database}
            label={disk.mount}
            percent={disk.percent_used * 1.0}
            detail={dgettext("dialogs", "%{total} total", total: Format.bytes(disk.total_kb * 1024))}
            testid={"system-os-disk-#{disk.mount}"}
          />
        </div>
      </section>
    </div>
    """
  end

  attr :icon, :atom, required: true
  attr :label, :string, required: true
  attr :percent, :float, required: true
  attr :detail, :string, default: nil
  attr :testid, :string, required: true

  defp host_gauge(assigns) do
    ~H"""
    <div
      class="min-w-0 shrink-0 border border-border bg-surface p-2 shadow-retro-sunken"
      data-testid={@testid}
    >
      <div class="mb-1 flex min-w-0 items-center gap-1">
        {apply(Icons, @icon, [%{class: "h-3.5 w-3.5 shrink-0"}])}
        <span class="min-w-0 flex-1 truncate text-xs font-bold">{@label}</span>
        <span class="shrink-0 text-xs font-bold tabular-nums">{Format.percent(@percent)}</span>
      </div>

      <.progress value={round(@percent)} class="h-3" />

      <p :if={@detail} class="mt-1 truncate text-[10px] leading-3 text-muted-foreground">
        {@detail}
      </p>
    </div>
    """
  end

  # An unreadable gauge says so. Rendering it as zero would claim the host is
  # idle, which is a different and much more dangerous statement.
  defp reading(nil, _formatter), do: "—"
  defp reading(value, formatter), do: formatter.(value)

  defp load(value), do: :erlang.float_to_binary(value, decimals: 2)

  defp load_detail(%{logical_processors: nil}), do: nil

  defp load_detail(%{logical_processors: count}) do
    dgettext("dialogs", "across %{count} processors", count: count)
  end
end
