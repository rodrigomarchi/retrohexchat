defmodule RetroHexChatWeb.Components.UI.System.ObanPanel do
  @moduledoc """
  Presentation for Oban queue health and RSS successor coverage.
  """

  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.AdminShared
  import RetroHexChatWeb.Components.UI.MediaSession.SummaryCard

  alias RetroHexChatWeb.Components.UI.Format
  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :snapshot, :any, required: true, doc: "%Jobs.ObanHealth.Snapshot{}"
  attr :filters, :list, default: []
  attr :target, :any, default: nil
  attr :on_refresh, :string, required: true
  attr :on_filter, :string, required: true
  attr :testid, :string, default: "system-oban"

  @spec oban_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def oban_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-oban"}
      class="adm-dialog retro-scrollbar flex h-full min-h-0 flex-col gap-retro-8 overflow-y-auto"
      data-testid={@testid}
    >
      <section class="shrink-0">
        <.section_heading icon={:icon_status_signal} label={dgettext("dialogs", "Oban health")}>
          <.refresh_button target={@target} on_refresh={@on_refresh} />
        </.section_heading>

        <div class="grid grid-cols-2 gap-retro-6 lg:grid-cols-4">
          <.summary_card
            variant={:prominent}
            icon={:icon_status_signal}
            label={dgettext("dialogs", "Status")}
            value={status_label(@snapshot.status)}
            detail={running_label(@snapshot.summary.running?)}
            tone_class={status_class(@snapshot.status)}
            testid="system-oban-status"
          />
          <.summary_card
            variant={:prominent}
            icon={:icon_table_grid}
            label={dgettext("dialogs", "Active jobs")}
            value={Format.number(@snapshot.summary.active_jobs)}
            detail={
              dgettext("dialogs", "%{count} executing",
                count: Format.number(@snapshot.summary.executing_jobs)
              )
            }
            testid="system-oban-active"
          />
          <.summary_card
            variant={:prominent}
            icon={:icon_warning}
            label={dgettext("dialogs", "Failures")}
            value={Format.number(@snapshot.summary.retryable_jobs + @snapshot.summary.discarded_jobs)}
            detail={
              dgettext("dialogs", "%{count} retryable",
                count: Format.number(@snapshot.summary.retryable_jobs)
              )
            }
            tone_class={failure_class(@snapshot.summary)}
            testid="system-oban-failures"
          />
          <.summary_card
            variant={:prominent}
            icon={:icon_btn_bot_management}
            label={dgettext("dialogs", "RSS feeds")}
            value={rss_coverage(@snapshot.summary)}
            detail={
              dgettext("dialogs", "%{count} missing jobs",
                count: Format.number(@snapshot.summary.rss_missing_jobs)
              )
            }
            tone_class={rss_class(@snapshot.summary)}
            testid="system-oban-rss"
          />
        </div>

        <div class="mt-retro-6 grid gap-retro-4 border border-border bg-surface p-2 text-[11px] shadow-retro-sunken sm:grid-cols-2">
          <.config_item label={dgettext("dialogs", "Supervisor")} value={@snapshot.config.name} />
          <.config_item label={dgettext("dialogs", "Node")} value={@snapshot.config.node} />
          <.config_item label={dgettext("dialogs", "Engine")} value={@snapshot.config.engine} />
          <.config_item label={dgettext("dialogs", "Repo")} value={@snapshot.config.repo} />
          <.config_item label={dgettext("dialogs", "Queues")} value={queue_config(@snapshot.config)} />
          <.config_item label={dgettext("dialogs", "Plugins")} value={plugins(@snapshot.config)} />
        </div>
      </section>

      <section :if={@snapshot.status_reasons != []} class="shrink-0">
        <ul class="space-y-retro-2 bg-black p-retro-6 font-mono text-xs shadow-retro-sunken">
          <li
            :for={reason <- @snapshot.status_reasons}
            class={status_reason_class(@snapshot.status)}
          >
            {reason}
          </li>
        </ul>
      </section>

      <section class="min-h-[220px] shrink-0">
        <.section_heading icon={:icon_table_grid} label={dgettext("dialogs", "Queues by state")} />
        <div class="retro-scrollbar max-h-[260px] overflow-auto bg-white shadow-retro-sunken">
          <.admin_table
            table={@snapshot.queue_table}
            testid={"#{@testid}-queues-table"}
            truncate
            empty_title={dgettext("dialogs", "No Oban queues or jobs were found")}
          />
        </div>
      </section>

      <section class="min-h-[220px] shrink-0">
        <.section_heading icon={:icon_clock} label={dgettext("dialogs", "Recent jobs")}>
          <form
            id={"#{@id}-filter"}
            phx-change={@on_filter}
            phx-submit={@on_filter}
            phx-target={@target}
          >
            <label for={"#{@id}-job-filter"} class="sr-only">
              {dgettext("dialogs", "Job filter")}
            </label>
            <select
              id={"#{@id}-job-filter"}
              name="filter"
              class="bg-white px-retro-4 py-retro-2 text-xs shadow-retro-sunken"
            >
              <option
                :for={filter <- @filters}
                value={filter.id}
                selected={filter.id == @snapshot.job_filter}
              >
                {filter_label(filter)}
              </option>
            </select>
          </form>
        </.section_heading>

        <div class="retro-scrollbar max-h-[260px] overflow-auto bg-white shadow-retro-sunken">
          <.admin_table
            table={@snapshot.jobs_table}
            testid={"#{@testid}-jobs-table"}
            truncate
            empty_title={dgettext("dialogs", "No jobs matched this filter")}
          />
        </div>
      </section>

      <section class="min-h-[220px] shrink-0">
        <.section_heading
          icon={:icon_btn_bot_management}
          label={dgettext("dialogs", "RSS feed coverage")}
        />
        <div class="retro-scrollbar max-h-[260px] overflow-auto bg-white shadow-retro-sunken">
          <.admin_table
            table={@snapshot.rss_table}
            testid={"#{@testid}-rss-table"}
            truncate
            empty_title={dgettext("dialogs", "No RSS feeds are configured")}
          />
        </div>
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

  attr :label, :string, required: true
  attr :value, :string, default: nil

  defp config_item(assigns) do
    ~H"""
    <div class="min-w-0">
      <span class="block truncate font-bold uppercase text-muted-foreground">{@label}</span>
      <span class="block truncate font-mono" title={@value || ""}>{@value || "—"}</span>
    </div>
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
      data-testid="system-oban-refresh"
    >
      <Icons.icon_btn_refresh class="h-[14px] w-[14px]" />
    </button>
    """
  end

  defp status_label(:healthy), do: dgettext("dialogs", "Healthy")
  defp status_label(:warning), do: dgettext("dialogs", "Warning")
  defp status_label(:critical), do: dgettext("dialogs", "Critical")

  defp status_class(:healthy), do: "text-green-700"
  defp status_class(:warning), do: "text-yellow-700"
  defp status_class(:critical), do: "text-red-700"

  defp status_reason_class(:healthy), do: "text-green-400"
  defp status_reason_class(:warning), do: "text-yellow-400"
  defp status_reason_class(:critical), do: "text-red-400"

  defp running_label(true), do: dgettext("dialogs", "supervisor running")
  defp running_label(false), do: dgettext("dialogs", "supervisor unavailable")

  defp failure_class(%{retryable_jobs: 0, discarded_jobs: 0}), do: nil
  defp failure_class(_summary), do: "text-red-700"

  defp rss_class(%{rss_missing_jobs: 0, rss_feed_errors: 0}), do: nil
  defp rss_class(_summary), do: "text-red-700"

  defp rss_coverage(%{rss_feeds: 0}), do: "0/0"

  defp rss_coverage(summary) do
    healthy = summary.rss_feeds - summary.rss_missing_jobs - summary.rss_feed_errors
    "#{Format.number(max(healthy, 0))}/#{Format.number(summary.rss_feeds)}"
  end

  defp queue_config(%{queues: []}), do: "—"

  defp queue_config(%{queues: queues}) do
    Enum.map_join(queues, ", ", fn queue ->
      if queue.limit, do: "#{queue.name}:#{queue.limit}", else: queue.name
    end)
  end

  defp plugins(%{plugins: []}), do: "—"
  defp plugins(%{plugins: plugins}), do: Enum.join(plugins, ", ")

  defp filter_label(%{id: "active"}), do: dgettext("dialogs", "Active")
  defp filter_label(%{id: "failures"}), do: dgettext("dialogs", "Failures")
  defp filter_label(%{id: "discarded"}), do: dgettext("dialogs", "Discarded")
  defp filter_label(%{id: "all"}), do: dgettext("dialogs", "All")
  defp filter_label(filter), do: filter.label
end
