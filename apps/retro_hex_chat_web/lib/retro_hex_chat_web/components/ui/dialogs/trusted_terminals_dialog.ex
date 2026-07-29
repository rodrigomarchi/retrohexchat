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
  import RetroHexChatWeb.Components.UI.Tabs
  import RetroHexChatWeb.Components.UI.TrustedDevices.TrustedTerminalCard

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
  attr :active_tab, :string, default: "devices"
  attr :status_kind, :atom, default: nil
  attr :status_message, :string, default: nil
  attr :on_tab, :any, default: nil
  attr :on_close, :any, default: nil

  @spec trusted_terminals_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def trusted_terminals_panel(assigns) do
    assigns = assign(assigns, :active_tab, trusted_tab(assigns.active_tab))

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
          class="flex h-full min-h-0 flex-col text-xs outline-none"
        >
          <div class="min-h-0 flex-1 overflow-y-auto pr-1 retro-scrollbar">
            <div class="flex min-h-full flex-col gap-retro-8">
              <div class="grid gap-retro-8 md:grid-cols-[1fr_auto] md:items-start">
                <div class="grid gap-retro-6 sm:grid-cols-3">
                  <div class="grid min-w-0 grid-cols-[16px_minmax(0,1fr)] gap-x-retro-4">
                    <Icons.icon_status_user class="row-span-2 h-4 w-4 self-center" />
                    <span class="text-muted-foreground">{dgettext("dialogs", "Nickname:")}</span>
                    <span class="truncate font-bold">{@nickname}</span>
                  </div>

                  <div class="grid min-w-0 grid-cols-[16px_minmax(0,1fr)] gap-x-retro-4">
                    <.nickserv_icon
                      identified={@identified}
                      class="row-span-2 h-4 w-4 self-center"
                    />
                    <span class="text-muted-foreground">{dgettext("dialogs", "NickServ:")}</span>
                    <span class="truncate font-bold">
                      {if @identified,
                        do: dgettext("dialogs", "Identified"),
                        else: dgettext("dialogs", "Not identified")}
                    </span>
                  </div>

                  <div class="grid min-w-0 grid-cols-[16px_minmax(0,1fr)] gap-x-retro-4">
                    <.current_terminal_icon
                      current_device_id={@current_device_id}
                      class="row-span-2 h-4 w-4 self-center"
                    />
                    <span class="text-muted-foreground">{dgettext("dialogs", "This terminal:")}</span>
                    <span class="truncate font-bold">
                      {current_terminal_label(@current_device_id)}
                    </span>
                  </div>
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

              <.tabs
                :let={builder}
                :if={@identified}
                id={"#{@id}-tabs"}
                default={@active_tab}
                data-active-tab={@active_tab}
                class="flex min-h-0 flex-1 flex-col overflow-hidden"
              >
                <.tabs_list class="flex-wrap">
                  <.tabs_trigger
                    builder={builder}
                    value="devices"
                    phx-click={@on_tab}
                    phx-target={@target}
                    phx-value-tab="devices"
                    data-testid="trusted-terminals-tab-devices"
                  >
                    <:icon><Icons.icon_laptop class="w-4 h-4" /></:icon>
                    {dgettext("dialogs", "Trusted Terminals")}
                  </.tabs_trigger>
                  <.tabs_trigger
                    builder={builder}
                    value="sessions"
                    phx-click={@on_tab}
                    phx-target={@target}
                    phx-value-tab="sessions"
                    data-testid="trusted-terminals-tab-sessions"
                  >
                    <:icon><Icons.icon_status_signal class="w-4 h-4" /></:icon>
                    {dgettext("dialogs", "Active Sessions")}
                  </.tabs_trigger>
                  <.tabs_trigger
                    builder={builder}
                    value="events"
                    phx-click={@on_tab}
                    phx-target={@target}
                    phx-value-tab="events"
                    data-testid="trusted-terminals-tab-events"
                  >
                    <:icon><Icons.icon_clock class="w-4 h-4" /></:icon>
                    {dgettext("dialogs", "Recent Activity")}
                  </.tabs_trigger>
                </.tabs_list>

                <.tabs_content value="devices" builder={builder} class="flex min-h-0 flex-1 flex-col">
                  <div class="min-h-[240px] flex-1 overflow-y-auto bg-white p-1 shadow-retro-field retro-scrollbar">
                    <.list_empty_state
                      :if={@devices == []}
                      title={dgettext("dialogs", "No trusted terminals for this nickname.")}
                    />

                    <.trusted_terminal_card
                      :for={device <- @devices}
                      entry={device}
                      nickname={@nickname}
                      current={device.current?}
                      timezone={@timezone}
                      show_audit_metadata
                      on_auto_login_toggle="trusted_terminals_auto_login_toggle"
                      auto_login_target={@target}
                      auto_login_testid={"trusted-device-auto-login-#{device.id}"}
                      testid={"trusted-device-#{device.id}"}
                      class="mb-retro-4 last:mb-0"
                    >
                      <:actions :let={terminal}>
                        <.button
                          type="button"
                          size="sm"
                          variant={if terminal.current, do: "destructive", else: "outline"}
                          phx-click={
                            if terminal.current,
                              do: "trusted_terminals_forget_current",
                              else: "trusted_terminals_revoke_device"
                          }
                          phx-target={@target}
                          phx-value-id={terminal.device_id}
                          data-testid={"trusted-device-revoke-#{terminal.device_id}"}
                        >
                          <:icon><Icons.icon_trash class="w-4 h-4" /></:icon>
                          {if terminal.current,
                            do: dgettext("dialogs", "Forget"),
                            else: dgettext("dialogs", "Revoke")}
                        </.button>
                      </:actions>

                      <:management :let={terminal}>
                        <form
                          class="grid gap-retro-4 sm:grid-cols-[1fr_auto]"
                          phx-submit="trusted_terminals_rename_device"
                          phx-target={@target}
                          data-testid={"trusted-device-rename-form-#{terminal.device_id}"}
                        >
                          <input type="hidden" name="device_id" value={terminal.device_id} />
                          <.input
                            name="label"
                            value={terminal.terminal_label}
                            maxlength="100"
                            class="h-7 text-xs"
                            aria-label={dgettext("dialogs", "Terminal label")}
                          />
                          <.button type="submit" size="sm" variant="outline">
                            <:icon><Icons.icon_btn_save class="w-4 h-4" /></:icon>
                            {dgettext("dialogs", "Save")}
                          </.button>
                        </form>
                      </:management>
                    </.trusted_terminal_card>
                  </div>
                </.tabs_content>

                <.tabs_content
                  value="sessions"
                  builder={builder}
                  class="flex min-h-0 flex-1 flex-col gap-retro-4"
                >
                  <.list_empty_state
                    :if={State.empty?(@sessions_state)}
                    icon={:people}
                    title={dgettext("dialogs", "No active sessions.")}
                  />
                  <div
                    :if={not State.empty?(@sessions_state)}
                    id={"#{@id}-sessions"}
                    class="min-h-[240px] flex-1 overflow-y-auto bg-white p-1 shadow-retro-field retro-scrollbar"
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
                              class="inline-flex items-center gap-1 bg-selection-bg px-1 text-selection-fg"
                            >
                              <Icons.icon_checkmark class="h-3 w-3" />
                              {dgettext("dialogs", "Current")}
                            </span>
                          </div>
                          <div class="mt-2 grid gap-retro-2 text-muted-foreground sm:grid-cols-2 lg:grid-cols-4">
                            <.metadata_item
                              icon={:id}
                              value={dgettext("dialogs", "Session ID: #%{id}", id: session.id)}
                            />
                            <.metadata_item
                              icon={:fingerprint}
                              value={
                                field_label(
                                  dgettext("dialogs", "Ref"),
                                  short_fingerprint(session.session_ref)
                                )
                              }
                              fallback={dgettext("dialogs", "No ref")}
                            />
                            <.metadata_item
                              icon={:id}
                              value={session_device_id_label(session.device_id)}
                            />
                            <.metadata_item
                              icon={:browser}
                              value={field_label(dgettext("dialogs", "Browser"), session.browser)}
                              fallback={dgettext("dialogs", "Unknown browser")}
                            />
                            <.metadata_item
                              icon={:os}
                              value={field_label(dgettext("dialogs", "OS"), session.os)}
                              fallback={dgettext("dialogs", "Unknown OS")}
                            />
                            <.metadata_item
                              icon={:type}
                              value={
                                field_label(
                                  dgettext("dialogs", "Type"),
                                  device_type_label(session.device_type)
                                )
                              }
                              fallback={dgettext("dialogs", "Unknown type")}
                            />
                            <.metadata_item
                              icon={:language}
                              value={field_label(dgettext("dialogs", "Language"), session.language)}
                              fallback={dgettext("dialogs", "Unknown language")}
                            />
                            <.metadata_item
                              icon={:display}
                              value={field_label(dgettext("dialogs", "Screen"), session.screen)}
                              fallback={dgettext("dialogs", "Unknown screen")}
                            />
                            <.metadata_item
                              icon={:timezone}
                              value={field_label(dgettext("dialogs", "TZ"), session.timezone)}
                              fallback={dgettext("dialogs", "Unknown timezone")}
                            />
                            <.metadata_item
                              icon={:color_depth}
                              value={
                                field_label(
                                  dgettext("dialogs", "Depth"),
                                  color_depth_label(session.color_depth)
                                )
                              }
                              fallback={dgettext("dialogs", "Unknown depth")}
                            />
                            <.metadata_item
                              icon={:cores}
                              value={
                                field_label(dgettext("dialogs", "CPU"), cores_label(session.cores))
                              }
                              fallback={dgettext("dialogs", "Unknown CPU")}
                            />
                            <.metadata_item
                              icon={:touch}
                              value={touch_label(session.touch)}
                              fallback={dgettext("dialogs", "Touch unknown")}
                            />
                            <.metadata_item
                              icon={:connect}
                              value={
                                dgettext("dialogs", "Connected: %{time}",
                                  time: format_dt(session.connected_at, @timezone)
                                )
                              }
                            />
                            <.metadata_item
                              icon={:last_seen}
                              value={
                                dgettext("dialogs", "Seen: %{time}",
                                  time: format_dt(session.last_seen_at, @timezone)
                                )
                              }
                            />
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
                    testid="trusted-sessions-end"
                  />
                </.tabs_content>

                <.tabs_content
                  value="events"
                  builder={builder}
                  class="flex min-h-0 flex-1 flex-col gap-retro-4"
                >
                  <.list_empty_state
                    :if={State.empty?(@events_state)}
                    title={dgettext("dialogs", "No terminal activity yet.")}
                  />
                  <div
                    :if={not State.empty?(@events_state)}
                    id={"#{@id}-events"}
                    class="min-h-[240px] flex-1 overflow-y-auto bg-white p-1 shadow-retro-field retro-scrollbar"
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
                        <.event_icon action={event.action} class="h-4 w-4 shrink-0" />
                        <span class="font-bold">{event_label(event.action)}</span>
                      </div>
                      <div class="grid gap-retro-2 text-muted-foreground sm:grid-cols-2 lg:grid-cols-4">
                        <.metadata_item
                          icon={:id}
                          value={dgettext("dialogs", "Event ID: #%{id}", id: event.id)}
                        />
                        <.metadata_item
                          icon={:clock}
                          value={
                            dgettext("dialogs", "Time: %{time}",
                              time: format_dt(event.inserted_at, @timezone)
                            )
                          }
                        />
                        <.metadata_item
                          icon={:actor}
                          value={field_label(dgettext("dialogs", "Actor"), event.actor_nickname)}
                          fallback={dgettext("dialogs", "No actor")}
                        />
                        <.metadata_item
                          icon={:id}
                          value={event_device_id_label(event.device_id)}
                        />
                        <.metadata_item
                          icon={:devices}
                          value={field_label(dgettext("dialogs", "Terminal"), event.device_label)}
                          fallback={dgettext("dialogs", "No terminal")}
                        />
                        <.metadata_item
                          icon={:tag}
                          value={field_label(dgettext("dialogs", "Action"), event.action)}
                        />
                      </div>

                      <div
                        :if={event_details(event.details) != []}
                        class="flex flex-wrap gap-retro-4 text-muted-foreground"
                      >
                        <span
                          :for={{key, value} <- event_details(event.details)}
                          class="inline-flex min-w-0 items-center gap-retro-4"
                        >
                          <Icons.icon_tag class="h-3.5 w-3.5 shrink-0" />
                          <span class="font-bold">{key}:</span>
                          <span class="truncate font-mono">{value}</span>
                        </span>
                      </div>
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
                    testid="trusted-events-end"
                  />
                </.tabs_content>
              </.tabs>
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

  defp trusted_tab(tab) when tab in ["devices", "sessions", "events"], do: tab
  defp trusted_tab(_tab), do: "devices"

  attr :identified, :boolean, default: false
  attr :class, :string, default: nil

  defp nickserv_icon(%{identified: true} = assigns) do
    ~H"""
    <Icons.icon_shield class={@class} />
    """
  end

  defp nickserv_icon(assigns) do
    ~H"""
    <Icons.icon_lock class={@class} />
    """
  end

  attr :current_device_id, :any, default: nil
  attr :class, :string, default: nil

  defp current_terminal_icon(%{current_device_id: nil} = assigns) do
    ~H"""
    <Icons.icon_lock class={@class} />
    """
  end

  defp current_terminal_icon(assigns) do
    ~H"""
    <Icons.icon_laptop class={@class} />
    """
  end

  attr :icon, :atom, required: true
  attr :value, :any, default: nil
  attr :fallback, :string, default: nil

  defp metadata_item(assigns) do
    ~H"""
    <span class="inline-flex min-w-0 items-center gap-retro-4">
      <.metadata_icon icon={@icon} class="h-3.5 w-3.5 shrink-0" />
      <span class="truncate">{metadata_value(@value, @fallback)}</span>
    </span>
    """
  end

  attr :icon, :atom, required: true
  attr :class, :string, default: nil

  defp metadata_icon(%{icon: :browser} = assigns) do
    ~H"""
    <Icons.icon_browser class={@class} />
    """
  end

  defp metadata_icon(%{icon: :os} = assigns) do
    ~H"""
    <Icons.icon_operating_system class={@class} />
    """
  end

  defp metadata_icon(%{icon: :display} = assigns) do
    ~H"""
    <Icons.icon_tab_display class={@class} />
    """
  end

  defp metadata_icon(%{icon: :timezone} = assigns) do
    ~H"""
    <Icons.icon_globe class={@class} />
    """
  end

  defp metadata_icon(%{icon: :type} = assigns) do
    ~H"""
    <Icons.icon_devices class={@class} />
    """
  end

  defp metadata_icon(%{icon: :language} = assigns) do
    ~H"""
    <Icons.icon_globe class={@class} />
    """
  end

  defp metadata_icon(%{icon: :color_depth} = assigns) do
    ~H"""
    <Icons.icon_tab_colors class={@class} />
    """
  end

  defp metadata_icon(%{icon: :cores} = assigns) do
    ~H"""
    <Icons.icon_database class={@class} />
    """
  end

  defp metadata_icon(%{icon: :touch} = assigns) do
    ~H"""
    <Icons.icon_call_devices class={@class} />
    """
  end

  defp metadata_icon(%{icon: :grant} = assigns) do
    ~H"""
    <Icons.icon_shield class={@class} />
    """
  end

  defp metadata_icon(%{icon: :connect} = assigns) do
    ~H"""
    <Icons.icon_connect class={@class} />
    """
  end

  defp metadata_icon(%{icon: :expires} = assigns) do
    ~H"""
    <Icons.icon_warning class={@class} />
    """
  end

  defp metadata_icon(%{icon: :last_seen} = assigns) do
    ~H"""
    <Icons.icon_clock class={@class} />
    """
  end

  defp metadata_icon(%{icon: :clock} = assigns) do
    ~H"""
    <Icons.icon_clock class={@class} />
    """
  end

  defp metadata_icon(%{icon: :actor} = assigns) do
    ~H"""
    <Icons.icon_status_user class={@class} />
    """
  end

  defp metadata_icon(%{icon: :devices} = assigns) do
    ~H"""
    <Icons.icon_laptop class={@class} />
    """
  end

  defp metadata_icon(assigns) do
    ~H"""
    <Icons.icon_tag class={@class} />
    """
  end

  attr :action, :string, required: true
  attr :class, :string, default: nil

  defp event_icon(%{action: "device.created"} = assigns) do
    ~H"""
    <Icons.icon_laptop class={@class} />
    """
  end

  defp event_icon(%{action: "device.nick.granted"} = assigns) do
    ~H"""
    <Icons.icon_shield class={@class} />
    """
  end

  defp event_icon(%{action: "device.nick.used"} = assigns) do
    ~H"""
    <Icons.icon_connect class={@class} />
    """
  end

  defp event_icon(%{action: action} = assigns)
       when action in [
              "device.nick.auto_login_enabled",
              "device.nick.auto_login_disabled"
            ] do
    ~H"""
    <Icons.icon_connect class={@class} />
    """
  end

  defp event_icon(%{action: "device.renamed"} = assigns) do
    ~H"""
    <Icons.icon_btn_edit class={@class} />
    """
  end

  defp event_icon(%{action: action} = assigns)
       when action in [
              "device.nick.revoked",
              "device.nick.revoked_all",
              "device.revoked"
            ] do
    ~H"""
    <Icons.icon_ban class={@class} />
    """
  end

  defp event_icon(%{action: "device.nick.signed_out"} = assigns) do
    ~H"""
    <Icons.icon_trash class={@class} />
    """
  end

  defp event_icon(%{action: "session.started"} = assigns) do
    ~H"""
    <Icons.icon_status_signal class={@class} />
    """
  end

  defp event_icon(%{action: action} = assigns)
       when action in ["session.killed", "session.killed_all"] do
    ~H"""
    <Icons.icon_btn_disconnect class={@class} />
    """
  end

  defp event_icon(assigns) do
    ~H"""
    <Icons.icon_clock class={@class} />
    """
  end

  defp current_terminal_label(nil), do: dgettext("dialogs", "Not remembered")
  defp current_terminal_label(_id), do: dgettext("dialogs", "Remembered")

  defp field_label(_label, nil), do: nil
  defp field_label(_label, ""), do: nil
  defp field_label(label, value), do: "#{label}: #{value}"

  defp device_type_label("desktop"), do: dgettext("dialogs", "Desktop")
  defp device_type_label("touch"), do: dgettext("dialogs", "Touch")
  defp device_type_label("unknown"), do: nil
  defp device_type_label(nil), do: nil
  defp device_type_label(type), do: type

  defp color_depth_label(bits) when is_integer(bits) and bits > 0 do
    dgettext("dialogs", "%{bits}-bit", bits: bits)
  end

  defp color_depth_label(_bits), do: nil

  defp cores_label(count) when is_integer(count) and count > 0 do
    dgettext("dialogs", "%{count} cores", count: count)
  end

  defp cores_label(_count), do: nil

  defp touch_label(true), do: dgettext("dialogs", "Touch: Yes")
  defp touch_label(false), do: dgettext("dialogs", "Touch: No")
  defp touch_label(_value), do: nil

  defp short_fingerprint(nil), do: nil
  defp short_fingerprint(""), do: nil

  defp short_fingerprint(value) when is_binary(value) do
    String.slice(value, 0, 12)
  end

  defp short_fingerprint(_value), do: nil

  defp session_device_id_label(nil), do: dgettext("dialogs", "Terminal ID: guest")
  defp session_device_id_label(id), do: dgettext("dialogs", "Terminal ID: #%{id}", id: id)

  defp event_device_id_label(nil), do: dgettext("dialogs", "Terminal ID: none")
  defp event_device_id_label(id), do: dgettext("dialogs", "Terminal ID: #%{id}", id: id)

  defp metadata_value(nil, fallback), do: fallback
  defp metadata_value("", fallback), do: fallback
  defp metadata_value(value, _fallback), do: value

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

  defp event_details(details) when is_map(details) do
    details
    |> Enum.reject(fn {_key, value} -> blank?(value) end)
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map(fn {key, value} -> {event_detail_key(key), event_detail_value(value)} end)
  end

  defp event_details(_details), do: []

  defp event_detail_key("count"), do: dgettext("dialogs", "Count")
  defp event_detail_key(:count), do: dgettext("dialogs", "Count")
  defp event_detail_key("grant_id"), do: dgettext("dialogs", "Grant ID")
  defp event_detail_key(:grant_id), do: dgettext("dialogs", "Grant ID")
  defp event_detail_key("label"), do: dgettext("dialogs", "Label")
  defp event_detail_key(:label), do: dgettext("dialogs", "Label")
  defp event_detail_key("session_id"), do: dgettext("dialogs", "Session ID")
  defp event_detail_key(:session_id), do: dgettext("dialogs", "Session ID")

  defp event_detail_key(key) do
    key
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp event_detail_value(value) when is_binary(value), do: value
  defp event_detail_value(value) when is_integer(value), do: Integer.to_string(value)
  defp event_detail_value(true), do: dgettext("dialogs", "yes")
  defp event_detail_value(false), do: dgettext("dialogs", "no")
  defp event_detail_value(value), do: inspect(value)

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_value), do: false

  defp event_label("device.created"), do: dgettext("dialogs", "Terminal created")
  defp event_label("device.nick.granted"), do: dgettext("dialogs", "Nick remembered")
  defp event_label("device.nick.used"), do: dgettext("dialogs", "Trusted login")

  defp event_label("device.nick.auto_login_enabled"),
    do: dgettext("dialogs", "Auto-login enabled")

  defp event_label("device.nick.auto_login_disabled"),
    do: dgettext("dialogs", "Auto-login disabled")

  defp event_label("device.renamed"), do: dgettext("dialogs", "Terminal renamed")
  defp event_label("device.nick.revoked"), do: dgettext("dialogs", "Terminal revoked")
  defp event_label("device.nick.signed_out"), do: dgettext("dialogs", "Terminal signed out")
  defp event_label("device.nick.revoked_all"), do: dgettext("dialogs", "All terminals revoked")
  defp event_label("session.started"), do: dgettext("dialogs", "Session started")
  defp event_label("session.killed"), do: dgettext("dialogs", "Session ended")
  defp event_label("session.killed_all"), do: dgettext("dialogs", "Sessions ended")
  defp event_label(_action), do: dgettext("dialogs", "Terminal activity")
end
