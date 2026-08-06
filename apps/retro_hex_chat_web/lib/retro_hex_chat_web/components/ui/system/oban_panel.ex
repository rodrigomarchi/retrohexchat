defmodule RetroHexChatWeb.Components.UI.System.ObanPanel do
  @moduledoc """
  Presentation for Oban queue health and durable job contracts.
  """

  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.RetroTable
  import RetroHexChatWeb.Components.UI.MediaSession.SummaryCard
  import RetroHexChatWeb.Components.UI.Tabs

  alias RetroHexChatWeb.Components.UI.Format
  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :snapshot, :any, required: true, doc: "%Jobs.ObanHealth.Snapshot{}"
  attr :filters, :list, default: []
  attr :target, :any, default: nil
  attr :active_tab, :string, default: "overview"
  attr :on_refresh, :string, required: true
  attr :on_filter, :string, required: true
  attr :on_tab, :string, required: true
  attr :testid, :string, default: "system-oban"

  @spec oban_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def oban_panel(assigns) do
    assigns =
      assigns
      |> assign(:active_tab, normalize_tab(assigns.active_tab))
      |> assign(:tabs, oban_tabs())

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

        <div class="grid grid-cols-2 gap-retro-6 lg:grid-cols-3 xl:grid-cols-5">
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
          <.summary_card
            variant={:prominent}
            icon={:icon_clock}
            label={dgettext("dialogs", "Bot schedules")}
            value={bot_schedule_coverage(@snapshot.summary)}
            detail={
              dgettext("dialogs", "%{count} missing jobs",
                count: Format.number(@snapshot.summary.bot_schedule_missing_jobs)
              )
            }
            tone_class={bot_schedule_class(@snapshot.summary)}
            testid="system-oban-bot-schedules"
          />
          <.summary_card
            variant={:prominent}
            icon={:icon_notepad}
            label={dgettext("dialogs", "Bot event logs")}
            value={Format.number(@snapshot.summary.bot_event_log_active)}
            detail={
              dgettext("dialogs", "%{count} failures",
                count: Format.number(@snapshot.summary.bot_event_log_failures)
              )
            }
            tone_class={bot_event_log_class(@snapshot.summary)}
            testid="system-oban-bot-event-logs"
          />
          <.summary_card
            variant={:prominent}
            icon={:icon_clock}
            label={dgettext("dialogs", "Maintenance")}
            value={maintenance_coverage(@snapshot.summary)}
            detail={
              dgettext("dialogs", "%{count} pending",
                count: Format.number(@snapshot.summary.maintenance_pending_work)
              )
            }
            tone_class={maintenance_class(@snapshot.summary)}
            testid="system-oban-maintenance"
          />
          <.summary_card
            variant={:prominent}
            icon={:icon_link}
            label={dgettext("dialogs", "Link previews")}
            value={link_preview_coverage(@snapshot.summary)}
            detail={
              dgettext("dialogs", "%{count} retrying",
                count: Format.number(@snapshot.summary.link_preview_retrying)
              )
            }
            tone_class={link_preview_class(@snapshot.summary)}
            testid="system-oban-link-preview"
          />
          <.summary_card
            variant={:prominent}
            icon={:icon_notepad}
            label={dgettext("dialogs", "Preference saves")}
            value={persistence_coverage(@snapshot.summary)}
            detail={
              dgettext("dialogs", "%{count} pending",
                count: Format.number(@snapshot.summary.persistence_pending)
              )
            }
            tone_class={persistence_class(@snapshot.summary)}
            testid="system-oban-persistence"
          />
        </div>
      </section>

      <.tabs
        :let={builder}
        id={"#{@id}-tabs"}
        default={@active_tab}
        data-active-tab={@active_tab}
        class="shrink-0"
      >
        <.tabs_list
          class="flex-wrap px-retro-2 pt-retro-4"
          role="tablist"
          aria-label={dgettext("dialogs", "Oban health sections")}
          data-testid={"#{@testid}-tabs"}
        >
          <.oban_tab
            :for={tab <- @tabs}
            builder={builder}
            tab={tab}
            active_tab={@active_tab}
            on_tab={@on_tab}
            target={@target}
            testid={@testid}
          />
        </.tabs_list>

        <.tabs_content
          value="overview"
          builder={builder}
          class="space-y-retro-8"
          role="tabpanel"
          data-testid={"#{@testid}-tabpanel-overview"}
        >
          <div class="grid gap-retro-4 border border-border bg-surface p-2 text-[11px] shadow-retro-sunken sm:grid-cols-2">
            <.config_item label={dgettext("dialogs", "Supervisor")} value={@snapshot.config.name} />
            <.config_item label={dgettext("dialogs", "Node")} value={@snapshot.config.node} />
            <.config_item label={dgettext("dialogs", "Engine")} value={@snapshot.config.engine} />
            <.config_item label={dgettext("dialogs", "Repo")} value={@snapshot.config.repo} />
            <.config_item
              label={dgettext("dialogs", "Queues")}
              value={queue_config(@snapshot.config)}
            />
            <.config_item label={dgettext("dialogs", "Plugins")} value={plugins(@snapshot.config)} />
          </div>

          <section :if={@snapshot.status_reasons != []}>
            <ul class="space-y-retro-2 bg-black p-retro-6 font-mono text-xs shadow-retro-sunken">
              <li
                :for={reason <- @snapshot.status_reasons}
                class={status_reason_class(@snapshot.status)}
              >
                {reason}
              </li>
            </ul>
          </section>
        </.tabs_content>

        <.tabs_content
          value="queues"
          builder={builder}
          class="space-y-retro-8"
          role="tabpanel"
          data-testid={"#{@testid}-tabpanel-queues"}
        >
          <section class="min-h-[220px]">
            <.section_heading
              icon={:icon_table_grid}
              label={dgettext("dialogs", "Queues by state")}
            />
            <.table_shell>
              <.retro_table
                id={"#{@testid}-queues-table"}
                table={@snapshot.queue_table}
                testid={"#{@testid}-queues-table"}
                truncate
                fit_pane
                empty_title={dgettext("dialogs", "No Oban queues or jobs were found")}
              />
            </.table_shell>
          </section>

          <section class="min-h-[220px]">
            <.section_heading icon={:icon_clock} label={dgettext("dialogs", "Recent jobs")}>
              <form
                id={"#{@id}-filter"}
                phx-change={@on_filter}
                phx-submit={@on_filter}
                phx-target={@target}
                class="flex min-w-0 flex-wrap items-center justify-end gap-retro-2"
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
                <label for={"#{@id}-queue-filter"} class="sr-only">
                  {dgettext("dialogs", "Queue filter")}
                </label>
                <input
                  id={"#{@id}-queue-filter"}
                  name="queue"
                  value={@snapshot.job_queue_filter}
                  placeholder={dgettext("dialogs", "Queue")}
                  class="w-20 bg-white px-retro-4 py-retro-2 text-xs shadow-retro-sunken"
                />
                <label for={"#{@id}-worker-filter"} class="sr-only">
                  {dgettext("dialogs", "Worker filter")}
                </label>
                <input
                  id={"#{@id}-worker-filter"}
                  name="worker"
                  value={@snapshot.job_worker_filter}
                  placeholder={dgettext("dialogs", "Worker")}
                  class="w-32 bg-white px-retro-4 py-retro-2 text-xs shadow-retro-sunken"
                />
              </form>
            </.section_heading>

            <.table_shell>
              <.retro_table
                id={"#{@testid}-jobs-table"}
                table={@snapshot.jobs_table}
                testid={"#{@testid}-jobs-table"}
                truncate
                fit_pane
                empty_title={dgettext("dialogs", "No jobs matched this filter")}
              />
            </.table_shell>
          </section>
        </.tabs_content>

        <.tabs_content
          value="bots"
          builder={builder}
          class="space-y-retro-8"
          role="tabpanel"
          data-testid={"#{@testid}-tabpanel-bots"}
        >
          <section class="min-h-[220px]">
            <.section_heading
              icon={:icon_btn_bot_management}
              label={dgettext("dialogs", "RSS feed coverage")}
            />
            <.table_shell>
              <.retro_table
                id={"#{@testid}-rss-table"}
                table={@snapshot.rss_table}
                testid={"#{@testid}-rss-table"}
                truncate
                fit_pane
                empty_title={dgettext("dialogs", "No RSS feeds are configured")}
              />
            </.table_shell>
          </section>

          <section class="min-h-[220px]">
            <.section_heading
              icon={:icon_clock}
              label={dgettext("dialogs", "Bot schedule coverage")}
            />
            <.table_shell>
              <.retro_table
                id={"#{@testid}-bot-schedules-table"}
                table={@snapshot.bot_schedule_table}
                testid={"#{@testid}-bot-schedules-table"}
                truncate
                fit_pane
                empty_title={dgettext("dialogs", "No bot schedules are configured")}
              />
            </.table_shell>
          </section>

          <section class="min-h-[220px]">
            <.section_heading icon={:icon_notepad} label={dgettext("dialogs", "Bot event log jobs")} />
            <.table_shell>
              <.retro_table
                id={"#{@testid}-bot-event-logs-table"}
                table={@snapshot.bot_event_log_table}
                testid={"#{@testid}-bot-event-logs-table"}
                truncate
                fit_pane
                empty_title={dgettext("dialogs", "No bot event log jobs are pending")}
              />
            </.table_shell>
          </section>
        </.tabs_content>

        <.tabs_content
          value="maintenance"
          builder={builder}
          class="space-y-retro-8"
          role="tabpanel"
          data-testid={"#{@testid}-tabpanel-maintenance"}
        >
          <section class="min-h-[220px]">
            <.section_heading icon={:icon_clock} label={dgettext("dialogs", "Maintenance sweeps")} />
            <.table_shell>
              <.retro_table
                id={"#{@testid}-maintenance-table"}
                table={@snapshot.maintenance_table}
                testid={"#{@testid}-maintenance-table"}
                truncate
                fit_pane
                empty_title={dgettext("dialogs", "No maintenance sweeps are configured")}
              />
            </.table_shell>
          </section>
        </.tabs_content>

        <.tabs_content
          value="previews"
          builder={builder}
          class="space-y-retro-8"
          role="tabpanel"
          data-testid={"#{@testid}-tabpanel-previews"}
        >
          <section class="min-h-[220px]">
            <.section_heading icon={:icon_link} label={dgettext("dialogs", "Link preview cache")} />
            <.table_shell>
              <.retro_table
                id={"#{@testid}-link-preview-table"}
                table={@snapshot.link_preview_table}
                testid={"#{@testid}-link-preview-table"}
                truncate
                fit_pane
                empty_title={dgettext("dialogs", "No link previews were cached")}
              />
            </.table_shell>
          </section>
        </.tabs_content>

        <.tabs_content
          value="persistence"
          builder={builder}
          class="space-y-retro-8"
          role="tabpanel"
          data-testid={"#{@testid}-tabpanel-persistence"}
        >
          <section class="min-h-[220px]">
            <.section_heading
              icon={:icon_notepad}
              label={dgettext("dialogs", "Preference persistence")}
            />
            <.table_shell>
              <.retro_table
                id={"#{@testid}-persistence-table"}
                table={@snapshot.persistence_table}
                testid={"#{@testid}-persistence-table"}
                truncate
                fit_pane
                empty_title={dgettext("dialogs", "No preference saves are pending")}
              />
            </.table_shell>
          </section>
        </.tabs_content>
      </.tabs>
    </div>
    """
  end

  attr :builder, :map, required: true
  attr :tab, :map, required: true
  attr :active_tab, :string, required: true
  attr :on_tab, :string, required: true
  attr :target, :any, default: nil
  attr :testid, :string, required: true

  defp oban_tab(assigns) do
    ~H"""
    <.tabs_trigger
      builder={@builder}
      value={@tab.id}
      phx-click={@on_tab}
      phx-target={@target}
      phx-value-tab={@tab.id}
      role="tab"
      aria-selected={to_string(@tab.id == @active_tab)}
      data-state={if(@tab.id == @active_tab, do: "active")}
      data-testid={"#{@testid}-tab-#{@tab.id}"}
    >
      <:icon>{apply(Icons, @tab.icon, [%{class: "h-[16px] w-[16px]"}])}</:icon>
      {@tab.label}
    </.tabs_trigger>
    """
  end

  slot :inner_block, required: true

  defp table_shell(assigns) do
    ~H"""
    <div class="retro-scrollbar max-h-[260px] overflow-auto bg-white shadow-retro-sunken">
      {render_slot(@inner_block)}
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

  defp oban_tabs do
    [
      %{id: "overview", icon: :icon_status_signal, label: dgettext("dialogs", "Overview")},
      %{id: "queues", icon: :icon_table_grid, label: dgettext("dialogs", "Queues")},
      %{id: "bots", icon: :icon_btn_bot_management, label: dgettext("dialogs", "Bots")},
      %{id: "maintenance", icon: :icon_clock, label: dgettext("dialogs", "Maintenance")},
      %{id: "previews", icon: :icon_link, label: dgettext("dialogs", "Previews")},
      %{id: "persistence", icon: :icon_notepad, label: dgettext("dialogs", "Persistence")}
    ]
  end

  defp normalize_tab(tab) do
    if Enum.any?(oban_tabs(), &(&1.id == tab)), do: tab, else: "overview"
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

  defp bot_schedule_class(%{bot_schedule_missing_jobs: 0, bot_schedule_failures: 0}), do: nil
  defp bot_schedule_class(_summary), do: "text-red-700"

  defp bot_event_log_class(%{bot_event_log_failures: 0}), do: nil
  defp bot_event_log_class(_summary), do: "text-red-700"

  defp maintenance_class(%{maintenance_failures: 0}), do: nil
  defp maintenance_class(_summary), do: "text-red-700"

  defp link_preview_class(%{link_preview_pending: 0}), do: nil
  defp link_preview_class(_summary), do: "text-yellow-700"

  defp persistence_class(%{persistence_failed: failed}) when failed > 0, do: "text-red-700"
  defp persistence_class(%{persistence_pending: pending}) when pending > 0, do: "text-yellow-700"
  defp persistence_class(_summary), do: nil

  defp rss_coverage(%{rss_feeds: 0}), do: "0/0"

  defp rss_coverage(summary) do
    healthy = summary.rss_feeds - summary.rss_missing_jobs - summary.rss_feed_errors
    "#{Format.number(max(healthy, 0))}/#{Format.number(summary.rss_feeds)}"
  end

  defp bot_schedule_coverage(%{bot_schedules: 0}), do: "0/0"

  defp bot_schedule_coverage(summary) do
    healthy =
      summary.bot_schedules - summary.bot_schedule_missing_jobs - summary.bot_schedule_failures

    "#{Format.number(max(healthy, 0))}/#{Format.number(summary.bot_schedules)}"
  end

  defp maintenance_coverage(%{maintenance_sweeps: 0}), do: "0/0"

  defp maintenance_coverage(summary) do
    healthy = summary.maintenance_sweeps - summary.maintenance_failures
    "#{Format.number(max(healthy, 0))}/#{Format.number(summary.maintenance_sweeps)}"
  end

  defp link_preview_coverage(%{link_previews: 0}), do: "0/0"

  defp link_preview_coverage(summary) do
    healthy = summary.link_previews - summary.link_preview_pending
    "#{Format.number(max(healthy, 0))}/#{Format.number(summary.link_previews)}"
  end

  defp persistence_coverage(%{persistence_requests: 0}), do: "0/0"

  defp persistence_coverage(summary) do
    healthy =
      summary.persistence_requests - summary.persistence_pending - summary.persistence_failed

    "#{Format.number(max(healthy, 0))}/#{Format.number(summary.persistence_requests)}"
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
