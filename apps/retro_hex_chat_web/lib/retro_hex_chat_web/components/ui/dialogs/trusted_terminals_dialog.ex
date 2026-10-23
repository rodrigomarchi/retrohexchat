defmodule RetroHexChatWeb.Components.UI.TrustedTerminalsDialog do
  @moduledoc """
  Trusted Terminals window body.

  Pure UI component. The LiveComponent supplies the read model, events and
  current-session context.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Inset
  import RetroHexChatWeb.Components.UI.ListStates

  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Tabs
  import RetroHexChatWeb.Components.UI.TrustedDevices.TrustedTerminalCard
  import RetroHexChatWeb.Components.UI.DialogBanner

  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PaginatedList.State

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
    assigns = assign(assigns, :device_lines, device_lines(assigns.devices))

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
          <div class="min-h-0 flex-1 overflow-y-auto pr-1">
            <div class="flex min-h-full flex-col gap-retro-8">
              <.dialog_banner heading={dgettext("dialogs", "Which machines can skip the password")}>
                <:art>
                  <Diagrams.diagram_dialog_preview
                    kind={:ordered}
                    title={dgettext("dialogs", "Connect")}
                    lines={@device_lines}
                    label={
                      dgettext(
                        "dialogs",
                        "A miniature of the Connect screen listing the machines that log in without a password"
                      )
                    }
                  />
                </:art>
                <:glyph><Icons.icon_lock class="h-8 w-8" /></:glyph>
                {dgettext(
                  "dialogs",
                  "A trusted terminal is a browser that may take this nickname back without typing the NickServ password. Revoking one makes that browser ask again; ending a session disconnects it now."
                )}
              </.dialog_banner>

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

              <div :if={!@identified} class="shadow-retro-field p-3">
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
                  <.inset class="min-h-[240px] flex-1 overflow-y-auto p-1">
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
                          variant="outline"
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
                  </.inset>
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
                  <.inset
                    :if={not State.empty?(@sessions_state)}
                    id={"#{@id}-sessions"}
                    class="min-h-[240px] flex-1 overflow-y-auto p-1"
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
                        <div class="min-w-0 flex-1">
                          <div class="flex items-center gap-retro-4">
                            <Icons.icon_status_signal class="h-4 w-4" />
                            <span class="truncate font-bold">{session.label}</span>
                            <.badge :if={session.current?} variant="success">
                              <:icon><Icons.icon_checkmark class="h-3 w-3" /></:icon>
                              {dgettext("dialogs", "Current")}
                            </.badge>
                          </div>
                          <div class="mt-2 flex flex-wrap gap-retro-4">
                            <.terminal_spec :for={spec <- device_specs(session)} spec={spec} />
                          </div>
                          <div class="mt-2 grid gap-retro-4 sm:grid-cols-2">
                            <.terminal_fact
                              :for={fact <- session_facts(session, @timezone)}
                              fact={fact}
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
                  </.inset>
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
                  <.inset
                    :if={not State.empty?(@events_state)}
                    id={"#{@id}-events"}
                    class="min-h-[240px] flex-1 overflow-y-auto p-1"
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
                      <div class="grid gap-retro-4 sm:grid-cols-2">
                        <.terminal_fact :for={fact <- event_facts(event, @timezone)} fact={fact} />
                      </div>
                    </div>
                  </.inset>
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

  defp status_class(:error), do: "text-error"
  defp status_class(:ok), do: "text-success"
  defp status_class(_kind), do: "text-muted-foreground"

  defp event_details(details) when is_map(details) do
    details
    |> Enum.reject(fn {_key, value} -> blank?(value) end)
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map(fn {key, value} -> {event_detail_key(key), event_detail_value(value)} end)
  end

  defp event_details(_details), do: []

  # What is known about a live session besides its device: which one it is,
  # the terminal it runs on, and when it came and was last heard from.
  @spec session_facts(map(), String.t()) :: [map()]
  defp session_facts(session, timezone) do
    [
      %{icon: :id, label: dgettext("dialogs", "Session ID"), value: "##{session.id}"},
      %{
        icon: :fingerprint,
        label: dgettext("dialogs", "Ref"),
        value: short_fingerprint(session.session_ref)
      },
      %{
        icon: :id,
        label: dgettext("dialogs", "Terminal ID"),
        value: terminal_id(session.device_id, dgettext("dialogs", "guest"))
      },
      %{
        icon: :connect,
        label: dgettext("dialogs", "Session started"),
        value: format_dt(session.connected_at, timezone)
      },
      %{
        icon: :last_seen,
        label: dgettext("dialogs", "Last activity"),
        value: format_dt(session.last_seen_at, timezone)
      }
    ]
    |> Enum.reject(&blank?(&1.value))
  end

  # What an event records: when, who did it, to which terminal, and the
  # details the action carried.
  @spec event_facts(map(), String.t()) :: [map()]
  defp event_facts(event, timezone) do
    details =
      Enum.map(event_details(event.details), fn {key, value} ->
        %{icon: :tag, label: key, value: value}
      end)

    ([
       %{icon: :id, label: dgettext("dialogs", "Event ID"), value: "##{event.id}"},
       %{
         icon: :first_seen,
         label: dgettext("dialogs", "Date of the event"),
         value: format_dt(event.inserted_at, timezone)
       },
       %{icon: :actor, label: dgettext("dialogs", "Actor"), value: event.actor_nickname},
       %{
         icon: :id,
         label: dgettext("dialogs", "Terminal ID"),
         value: terminal_id(event.device_id, nil)
       },
       %{icon: :terminal, label: dgettext("dialogs", "Terminal"), value: event.device_label},
       %{icon: :tag, label: dgettext("dialogs", "Action"), value: event.action}
     ] ++ details)
    |> Enum.reject(&blank?(&1.value))
  end

  @spec terminal_id(integer() | nil, String.t() | nil) :: String.t() | nil
  defp terminal_id(nil, fallback), do: fallback
  defp terminal_id(id, _fallback), do: "##{id}"

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

  # The picture is the Connect screen: the machines that will be offered
  # there, by the label their owner gave them.
  @spec device_lines([map()]) :: [map()]
  defp device_lines(devices) do
    Enum.map(devices, fn device ->
      %{text: Map.get(device, :label) || dgettext("dialogs", "Unnamed terminal"), tone: :accent}
    end)
  end
end
