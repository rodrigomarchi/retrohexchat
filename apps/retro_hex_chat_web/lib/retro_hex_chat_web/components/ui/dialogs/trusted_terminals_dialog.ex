defmodule RetroHexChatWeb.Components.UI.TrustedTerminalsDialog do
  @moduledoc """
  Trusted Terminals window body.

  Pure UI component. The LiveComponent supplies the read model, events and
  current-session context.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ListStates

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PaginatedList.State
  alias RetroHexChatWeb.Timezone

  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :nickname, :string, required: true
  attr :identified, :boolean, default: false
  attr :current_device_id, :integer, default: nil
  attr :current_session_ref, :string, default: nil
  attr :devices, :list, default: []
  attr :sessions, :any, default: [], doc: "Stream of live sessions"

  attr :sessions_state, :map,
    default: nil,
    doc: "PaginatedList.State for the sessions list; nil renders it without pagination"

  attr :events, :any, default: [], doc: "Stream of security events"

  attr :events_state, :map,
    default: nil,
    doc: "PaginatedList.State for the events list; nil renders it without pagination"

  attr :timezone, :string, default: "Etc/UTC"
  attr :status_kind, :atom, default: nil
  attr :status_message, :string, default: nil
  attr :on_close, :any, default: nil

  @spec trusted_terminals_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def trusted_terminals_panel(assigns) do
    ~H"""
    <div id={@id} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="trusted-terminals-panel"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "##{@id}-content")}
          class="flex h-full min-h-0 flex-col text-xs"
        >
          <div class="min-h-0 flex-1 overflow-y-auto pr-1 retro-scrollbar">
            <div class="flex min-h-full flex-col gap-retro-8">
              <div class="grid gap-retro-8 md:grid-cols-[1fr_auto] md:items-start">
                <div class="grid grid-cols-[112px_1fr] gap-retro-4">
                  <span class="font-bold">{dgettext("dialogs", "Nickname:")}</span>
                  <span class="min-w-0 truncate">{@nickname}</span>
                  <span class="font-bold">{dgettext("dialogs", "NickServ:")}</span>
                  <span>
                    {if @identified,
                      do: dgettext("dialogs", "Identified"),
                      else: dgettext("dialogs", "Not identified")}
                  </span>
                  <span class="font-bold">{dgettext("dialogs", "This terminal:")}</span>
                  <span>{current_terminal_label(@current_device_id)}</span>
                </div>

                <div class="flex flex-wrap gap-retro-4 md:justify-end">
                  <.button
                    type="button"
                    size="sm"
                    variant="outline"
                    phx-click="trusted_terminals_refresh"
                    phx-target={@target}
                    data-testid="trusted-terminals-refresh"
                  >
                    <:icon><Icons.icon_btn_refresh class="w-4 h-4" /></:icon>
                    {dgettext("dialogs", "Refresh")}
                  </.button>
                  <.button
                    :if={@identified}
                    type="button"
                    size="sm"
                    variant="outline"
                    phx-click="trusted_terminals_kill_other_sessions"
                    phx-target={@target}
                    data-testid="trusted-terminals-kill-others"
                  >
                    <:icon><Icons.icon_btn_disconnect class="w-4 h-4" /></:icon>
                    {dgettext("dialogs", "End Others")}
                  </.button>
                  <.button
                    :if={@identified}
                    type="button"
                    size="sm"
                    variant="destructive"
                    phx-click="trusted_terminals_revoke_all"
                    phx-target={@target}
                    data-testid="trusted-terminals-revoke-all"
                  >
                    <:icon><Icons.icon_trash class="w-4 h-4" /></:icon>
                    {dgettext("dialogs", "Revoke All")}
                  </.button>
                </div>
              </div>

              <p
                :if={@status_message}
                class={status_class(@status_kind)}
                data-testid="trusted-terminals-status"
              >
                {@status_message}
              </p>

              <div :if={!@identified} class="shadow-retro-field bg-canvas p-3">
                <div class="flex items-center gap-retro-4">
                  <Icons.icon_lock class="w-4 h-4" />
                  <span>
                    {dgettext("dialogs", "Identify with NickServ to manage trusted terminals.")}
                  </span>
                </div>
              </div>

              <div
                :if={@identified}
                class="grid min-h-0 flex-1 gap-retro-8 lg:grid-cols-[1.25fr_.9fr]"
              >
                <section class="flex min-h-0 flex-col gap-retro-4">
                  <.section_title icon={:devices} label={dgettext("dialogs", "Trusted Terminals")} />
                  <div class="min-h-[180px] flex-1 overflow-y-auto bg-white p-1 shadow-retro-field retro-scrollbar">
                    <.list_empty_state
                      :if={@devices == []}
                      title={dgettext("dialogs", "No trusted terminals for this nickname.")}
                    />

                    <div
                      :for={device <- @devices}
                      class="border-b border-border p-2 last:border-b-0"
                      data-testid={"trusted-device-#{device.id}"}
                    >
                      <div class="flex min-w-0 items-start justify-between gap-retro-6">
                        <div class="min-w-0">
                          <div class="flex min-w-0 items-center gap-retro-4">
                            <Icons.icon_laptop class="h-4 w-4 shrink-0" />
                            <span class="truncate font-bold">{device.label}</span>
                            <span
                              :if={device.current?}
                              class="shrink-0 bg-selection-bg px-1 text-selection-fg"
                            >
                              {dgettext("dialogs", "Current")}
                            </span>
                          </div>
                          <div class="mt-1 grid gap-retro-2 text-muted-foreground sm:grid-cols-2">
                            <span>{device.browser || dgettext("dialogs", "Unknown browser")}</span>
                            <span>{device.os || dgettext("dialogs", "Unknown OS")}</span>
                            <span>{device.screen || dgettext("dialogs", "Unknown screen")}</span>
                            <span>{device.timezone || dgettext("dialogs", "Unknown timezone")}</span>
                          </div>
                        </div>

                        <.button
                          type="button"
                          size="sm"
                          variant={if device.current?, do: "destructive", else: "outline"}
                          phx-click={
                            if device.current?,
                              do: "trusted_terminals_forget_current",
                              else: "trusted_terminals_revoke_device"
                          }
                          phx-target={@target}
                          phx-value-id={device.id}
                          data-testid={"trusted-device-revoke-#{device.id}"}
                        >
                          <:icon><Icons.icon_trash class="w-4 h-4" /></:icon>
                          {if device.current?,
                            do: dgettext("dialogs", "Forget"),
                            else: dgettext("dialogs", "Revoke")}
                        </.button>
                      </div>

                      <div class="mt-2 grid gap-retro-2 text-muted-foreground sm:grid-cols-3">
                        <span>
                          {dgettext("dialogs", "First: %{time}",
                            time: format_dt(device.first_seen_at, @timezone)
                          )}
                        </span>
                        <span>
                          {dgettext("dialogs", "Last: %{time}",
                            time: format_dt(device.last_seen_at, @timezone)
                          )}
                        </span>
                        <span>
                          {dgettext("dialogs", "Active: %{count}", count: device.active_sessions)}
                        </span>
                      </div>

                      <form
                        class="mt-2 grid gap-retro-4 sm:grid-cols-[1fr_auto]"
                        phx-submit="trusted_terminals_rename_device"
                        phx-target={@target}
                        data-testid={"trusted-device-rename-form-#{device.id}"}
                      >
                        <input type="hidden" name="device_id" value={device.id} />
                        <.input
                          name="label"
                          value={device.label}
                          maxlength="100"
                          class="h-7 text-xs"
                          aria-label={dgettext("dialogs", "Terminal label")}
                        />
                        <.button type="submit" size="sm" variant="outline">
                          <:icon><Icons.icon_btn_save class="w-4 h-4" /></:icon>
                          {dgettext("dialogs", "Save")}
                        </.button>
                      </form>
                    </div>
                  </div>
                </section>

                <div class="grid min-h-0 gap-retro-8">
                  <section class="flex min-h-0 flex-col gap-retro-4">
                    <.section_title icon={:sessions} label={dgettext("dialogs", "Active Sessions")} />
                    <.list_empty_state
                      :if={State.empty?(@sessions_state)}
                      icon={:people}
                      title={dgettext("dialogs", "No active sessions.")}
                    />
                    <div
                      :if={not State.empty?(@sessions_state)}
                      id={"#{@id}-sessions"}
                      class="max-h-[220px] min-h-[150px] overflow-y-auto bg-white p-1 shadow-retro-field retro-scrollbar"
                      phx-hook="InfiniteScrollHook"
                      phx-update="stream"
                      data-edge="bottom"
                      data-target={@target}
                      data-event="load_more_sessions"
                      data-has-more={to_string(State.more?(@sessions_state))}
                      data-loading={to_string(State.loading?(@sessions_state))}
                    >
                      <div
                        :for={{dom_id, session} <- @sessions}
                        id={dom_id}
                        class="border-b border-border p-2 last:border-b-0"
                        data-testid={"trusted-session-#{session.id}"}
                      >
                        <div class="flex items-start justify-between gap-retro-6">
                          <div class="min-w-0">
                            <div class="flex items-center gap-retro-4">
                              <Icons.icon_status_signal class="h-4 w-4" />
                              <span class="truncate font-bold">{session.label}</span>
                              <span
                                :if={session.current?}
                                class="bg-selection-bg px-1 text-selection-fg"
                              >
                                {dgettext("dialogs", "Current")}
                              </span>
                            </div>
                            <div class="mt-1 grid gap-retro-2 text-muted-foreground">
                              <span>{session.browser || dgettext("dialogs", "Unknown browser")}</span>
                              <span>{session.os || dgettext("dialogs", "Unknown OS")}</span>
                              <span>{format_dt(session.last_seen_at, @timezone)}</span>
                            </div>
                          </div>

                          <.button
                            type="button"
                            size="sm"
                            variant="outline"
                            phx-click="trusted_terminals_kill_session"
                            phx-target={@target}
                            phx-value-id={session.id}
                            data-testid={"trusted-session-kill-#{session.id}"}
                          >
                            <:icon><Icons.icon_btn_disconnect class="w-4 h-4" /></:icon>
                            {dgettext("dialogs", "End")}
                          </.button>
                        </div>
                      </div>
                    </div>
                    <.list_load_more_button
                      :if={State.more?(@sessions_state)}
                      target={@target}
                      event="load_more_sessions"
                      loading={State.loading?(@sessions_state)}
                      testid="trusted-sessions-load-more"
                    />
                    <.list_announcer state={@sessions_state} />
                    <.list_error_retry
                      :if={State.error?(@sessions_state)}
                      target={@target}
                      on_retry="load_more_sessions"
                      text={dgettext("dialogs", "Could not load more sessions.")}
                    />
                    <.list_end_marker
                      :if={State.exhausted?(@sessions_state)}
                      text={dgettext("dialogs", "No older sessions")}
                      testid="trusted-sessions-end"
                    />
                  </section>

                  <section class="flex min-h-0 flex-col gap-retro-4">
                    <.section_title icon={:events} label={dgettext("dialogs", "Recent Activity")} />
                    <.list_empty_state
                      :if={State.empty?(@events_state)}
                      title={dgettext("dialogs", "No terminal activity yet.")}
                    />
                    <div
                      :if={not State.empty?(@events_state)}
                      id={"#{@id}-events"}
                      class="max-h-[220px] min-h-[140px] overflow-y-auto bg-white p-1 shadow-retro-field retro-scrollbar"
                      phx-hook="InfiniteScrollHook"
                      phx-update="stream"
                      data-edge="bottom"
                      data-target={@target}
                      data-event="load_more_events"
                      data-has-more={to_string(State.more?(@events_state))}
                      data-loading={to_string(State.loading?(@events_state))}
                    >
                      <div
                        :for={{dom_id, event} <- @events}
                        id={dom_id}
                        class="grid gap-retro-2 border-b border-border p-2 last:border-b-0"
                        data-testid={"trusted-event-#{event.id}"}
                      >
                        <div class="flex items-center gap-retro-4">
                          <Icons.icon_clock class="h-4 w-4" />
                          <span class="font-bold">{event_label(event.action)}</span>
                        </div>
                        <div class="text-muted-foreground">{event_metadata(event, @timezone)}</div>
                      </div>
                    </div>
                    <.list_load_more_button
                      :if={State.more?(@events_state)}
                      target={@target}
                      event="load_more_events"
                      loading={State.loading?(@events_state)}
                      testid="trusted-events-load-more"
                    />
                    <.list_announcer state={@events_state} />
                    <.list_error_retry
                      :if={State.error?(@events_state)}
                      target={@target}
                      on_retry="load_more_events"
                      text={dgettext("dialogs", "Could not load more activity.")}
                    />
                    <.list_end_marker
                      :if={State.exhausted?(@events_state)}
                      text={dgettext("dialogs", "No older activity")}
                      testid="trusted-events-end"
                    />
                  </section>
                </div>
              </div>
            </div>
          </div>

          <div :if={@on_close} class="flex flex-none justify-end pt-retro-4">
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click={@on_close}
              phx-target={@target}
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Close")}
            </.button>
          </div>
        </div>
      </.focus_wrap>
    </div>
    """
  end

  attr :icon, :atom, required: true
  attr :label, :string, required: true

  defp section_title(assigns) do
    ~H"""
    <h3 class="flex items-center gap-retro-4 text-xs font-bold">
      <.section_icon icon={@icon} />
      {@label}
    </h3>
    """
  end

  attr :icon, :atom, required: true

  defp section_icon(%{icon: :sessions} = assigns),
    do: ~H"""
    <Icons.icon_status_signal class="h-4 w-4" />
    """

  defp section_icon(%{icon: :events} = assigns) do
    ~H"""
    <Icons.icon_clock class="h-4 w-4" />
    """
  end

  defp section_icon(assigns) do
    ~H"""
    <Icons.icon_devices class="h-4 w-4" />
    """
  end

  defp current_terminal_label(nil), do: dgettext("dialogs", "Not remembered")
  defp current_terminal_label(_id), do: dgettext("dialogs", "Remembered")

  defp status_class(:error), do: "text-error"
  defp status_class(:ok), do: "text-success"
  defp status_class(_kind), do: "text-muted-foreground"

  defp format_dt(nil, _timezone), do: dgettext("dialogs", "Never")

  defp format_dt(%DateTime{} = dt, timezone) do
    dt
    |> Timezone.shift(timezone)
    |> Calendar.strftime("%d/%m %H:%M")
  end

  defp format_dt(_dt, _timezone), do: dgettext("dialogs", "Unknown")

  defp event_metadata(event, timezone) do
    [format_dt(event.inserted_at, timezone), event.actor_nickname, event.device_label]
    |> Enum.reject(&blank?/1)
    |> Enum.join(" · ")
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_value), do: false

  defp event_label("device.created"), do: dgettext("dialogs", "Terminal created")
  defp event_label("device.nick.granted"), do: dgettext("dialogs", "Nick remembered")
  defp event_label("device.nick.used"), do: dgettext("dialogs", "Trusted login")
  defp event_label("device.renamed"), do: dgettext("dialogs", "Terminal renamed")
  defp event_label("device.nick.revoked"), do: dgettext("dialogs", "Terminal revoked")
  defp event_label("device.nick.signed_out"), do: dgettext("dialogs", "Terminal signed out")
  defp event_label("device.nick.revoked_all"), do: dgettext("dialogs", "All terminals revoked")
  defp event_label("session.started"), do: dgettext("dialogs", "Session started")
  defp event_label("session.killed"), do: dgettext("dialogs", "Session ended")
  defp event_label("session.killed_all"), do: dgettext("dialogs", "Sessions ended")
  defp event_label(_action), do: dgettext("dialogs", "Terminal activity")
end
