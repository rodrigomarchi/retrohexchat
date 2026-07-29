defmodule RetroHexChatWeb.Components.UI.ChatTaskbar do
  @moduledoc """
  Visual taskbar composition for the main chat desktop.

  The LiveView owns window state and session state. This component renders one
  taskbar read model twice: classic horizontal buttons on desktop, and a single
  mobile task switcher button that opens the same windows in a vertical list.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.StartMenuApp

  alias RetroHexChatWeb.Icons

  attr :open_windows, :any, default: MapSet.new()
  attr :is_admin, :boolean, default: false
  attr :p2p_session, :map, default: nil
  attr :group_call, :map, default: nil
  attr :arcade_session, :map, default: nil
  attr :cc_window_channel, :string, default: nil

  @spec chat_taskbar(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_taskbar(assigns) do
    windows = taskbar_windows(assigns)

    assigns =
      assign(assigns,
        taskbar_windows: windows,
        taskbar_slots: group_windows(windows)
      )

    ~H"""
    <.taskbar id="chat-taskbar">
      <:start>
        <.start_menu_app id="chat-start-menu" is_admin={@is_admin} p2p_active={@p2p_session != nil} />
      </:start>

      <%= for slot <- @taskbar_slots do %>
        <.taskbar_group
          :if={slot.kind == :group}
          label={slot.label}
          count={length(slot.windows)}
          testid={"taskbar-group-#{slot.family}"}
        >
          <:icon>{apply(Icons, slot.icon_fn, [%{class: "h-4 w-4"}])}</:icon>
          <.taskbar_button
            :for={window <- slot.windows}
            window={window.id}
            label={window.label}
            class="desktop-taskbar__group-item w-full"
            data-testid={Map.get(window, :testid)}
          >
            <:icon>{apply(Icons, window.icon_fn, [%{class: "h-4 w-4"}])}</:icon>
          </.taskbar_button>
        </.taskbar_group>

        <.taskbar_button
          :if={slot.kind == :window}
          window={slot.window.id}
          label={slot.window.label}
          class="desktop-taskbar__window-button"
          data-testid={Map.get(slot.window, :testid)}
        >
          <:icon>{apply(Icons, slot.window.icon_fn, [%{class: "h-4 w-4"}])}</:icon>
        </.taskbar_button>
      <% end %>

      <.mobile_task_switcher windows={@taskbar_windows} />

      <:tray>
        <.desktop_tray>
          <span id="chat-tray-clock" phx-hook="ClockHook" class="font-mono tabular-nums"></span>
        </.desktop_tray>
      </:tray>
    </.taskbar>
    """
  end

  attr :windows, :list, default: []

  defp mobile_task_switcher(assigns) do
    ~H"""
    <div class="mobile-task-switcher relative hidden min-w-0 flex-1">
      <button
        type="button"
        class="desktop-taskbar__button shadow-retro-raised bg-surface inline-flex min-w-0 w-full items-center gap-1 px-2 py-[2px] text-xs"
        data-mobile-task-switcher-trigger
        data-testid="mobile-task-switcher-trigger"
        aria-haspopup="menu"
        aria-expanded="false"
        aria-label={dgettext("ui", "Windows")}
      >
        <span class="inline-flex h-4 w-4 shrink-0 items-center justify-center">
          <Icons.icon_win_cascade class="h-4 w-4" />
        </span>
        <span class="truncate font-bold">{dgettext("ui", "Windows")}</span>
      </button>

      <div
        class="mobile-task-switcher__panel u-hidden shadow-retro-window bg-surface p-[3px]"
        data-mobile-task-switcher
        data-escape-guard
        role="menu"
        aria-label={dgettext("ui", "Windows")}
      >
        <ul class="list-none m-0 p-retro-2">
          <li :for={window <- @windows}>
            <button
              type="button"
              class="mobile-task-switcher__item flex w-full items-center gap-2 px-2 py-2 text-left text-xs hover:bg-selection-bg hover:text-selection-fg"
              data-window-taskbar={window.id}
              data-mobile-task-switcher-item
              data-testid={mobile_window_testid(window)}
              role="menuitem"
            >
              <span class="inline-flex h-4 w-4 shrink-0 items-center justify-center">
                {apply(Icons, window.icon_fn, [%{class: "h-4 w-4"}])}
              </span>
              <span class="min-w-0 flex-1 truncate">{window.label}</span>
            </button>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  # Window families that collapse into one taskbar entry. The taskbar is a
  # single `overflow-x-auto` strip of 12ch-truncated buttons, so 36 windows would
  # be ~4000px of horizontal scroll if every open one claimed its own button.
  #
  # A family collapses only while TWO OR MORE of its windows are open: grouping a
  # lone window would add a click and hide nothing. Order is preserved — the
  # group takes the position of its first member, so buttons never jump around as
  # sibling windows open.
  @families [
    {:admin, dgettext("chat", "Admin"), :icon_shield,
     ~w(admin-users admin-channels admin-server-settings admin-audit-log admin-motd admin-turn
        admin-broadcast admin-danger-zone admin-console)},
    {:account, dgettext("chat", "Account"), :icon_status_user,
     ~w(account trusted-terminals profile away user-modes)},
    {:contacts, dgettext("chat", "Contacts"), :icon_dialog_address_book,
     ~w(address-book nick-colors ignore-list notify-list)},
    {:connect, dgettext("chat", "On Connect"), :icon_dialog_perform, ~w(perform autojoin)}
  ]

  @doc false
  @spec group_windows([map()]) :: [map()]
  def group_windows(windows) do
    family_of = family_index()

    windows
    |> Enum.reduce({[], %{}}, fn window, {slots, seen} ->
      case Map.get(family_of, window.id) do
        nil -> {slots ++ [{:window, window}], seen}
        family -> {maybe_placeholder(slots, family, seen), Map.put(seen, family, true)}
      end
    end)
    |> then(fn {slots, _seen} -> Enum.map(slots, &expand_slot(&1, windows)) end)
  end

  defp maybe_placeholder(slots, family, seen) do
    if Map.has_key?(seen, family), do: slots, else: slots ++ [{:family, family}]
  end

  defp expand_slot({:window, window}, _windows), do: %{kind: :window, window: window}

  defp expand_slot({:family, family}, windows) do
    {^family, label, icon_fn, ids} = Enum.find(@families, &(elem(&1, 0) == family))
    members = Enum.filter(windows, &(&1.id in ids))

    case members do
      [only] -> %{kind: :window, window: only}
      many -> %{kind: :group, family: family, label: label, icon_fn: icon_fn, windows: many}
    end
  end

  defp family_index do
    for {family, _label, _icon, ids} <- @families, id <- ids, into: %{}, do: {id, family}
  end

  defp taskbar_windows(assigns) do
    [
      %{id: "chat", label: dgettext("chat", "RetroHexChat"), icon_fn: :icon_chat},
      %{id: "url-catcher", label: dgettext("chat", "URL Catcher"), icon_fn: :icon_link},
      %{id: "channel-list", label: dgettext("chat", "Channel List"), icon_fn: :icon_channels}
    ]
    |> add_window(
      window_open?(assigns.open_windows, "cheatsheet"),
      "cheatsheet",
      dgettext("chat", "Keyboard Shortcuts"),
      :icon_dialog_cheatsheet
    )
    |> add_window(
      assigns.cc_window_channel,
      "channel-central",
      dgettext("chat", "Channel Central"),
      :icon_dialog_channel_central
    )
    |> add_window(
      window_open?(assigns.open_windows, "account"),
      "account",
      dgettext("chat", "Account"),
      :icon_status_user
    )
    |> add_window(
      window_open?(assigns.open_windows, "trusted-terminals"),
      "trusted-terminals",
      dgettext("chat", "Trusted Terminals"),
      :icon_lock
    )
    |> add_window(
      window_open?(assigns.open_windows, "profile"),
      "profile",
      dgettext("chat", "Profile"),
      :icon_dialog_profile
    )
    |> add_window(
      window_open?(assigns.open_windows, "away"),
      "away",
      dgettext("chat", "Away"),
      :icon_dialog_away
    )
    |> add_window(
      window_open?(assigns.open_windows, "user-modes"),
      "user-modes",
      dgettext("chat", "User Modes"),
      :icon_dialog_user_modes
    )
    |> add_window(
      window_open?(assigns.open_windows, "user-lookup"),
      "user-lookup",
      dgettext("chat", "User Lookup"),
      :icon_btn_search
    )
    |> add_admin_windows(assigns)
    |> add_window(
      assigns.is_admin && window_open?(assigns.open_windows, "bot-management-dialog"),
      "bot-management-dialog",
      dgettext("chat", "Bot Management"),
      :icon_btn_bot_management
    )
    |> add_window(
      window_open?(assigns.open_windows, "timers"),
      "timers",
      dgettext("chat", "Timers"),
      :icon_btn_timers
    )
    |> add_window(
      assigns.p2p_session,
      "p2p-call",
      p2p_call_label(assigns.p2p_session),
      :icon_protocol_p2p_compact,
      testid: "p2p-call-taskbar"
    )
    |> add_window(
      assigns.group_call,
      "group-call",
      group_call_label(assigns.group_call),
      :icon_protocol_conference_compact,
      testid: "group-call-taskbar"
    )
    |> add_window(
      assigns.arcade_session && window_open?(assigns.open_windows, "arcade-games"),
      "arcade-games",
      dgettext("chat", "Arcade"),
      :icon_game_arcade
    )
    |> add_window(
      window_open?(assigns.open_windows, "highlight"),
      "highlight",
      dgettext("chat", "Highlight Words"),
      :icon_star
    )
    |> add_window(
      window_open?(assigns.open_windows, "sound-settings"),
      "sound-settings",
      dgettext("chat", "Sound Settings"),
      :icon_dialog_sound
    )
    |> add_window(
      window_open?(assigns.open_windows, "flood-protection"),
      "flood-protection",
      dgettext("chat", "Flood Protection"),
      :icon_dialog_flood
    )
    |> add_window(
      window_open?(assigns.open_windows, "alias"),
      "alias",
      dgettext("chat", "Alias Editor"),
      :icon_dialog_alias
    )
    |> add_window(
      window_open?(assigns.open_windows, "custom-menus"),
      "custom-menus",
      dgettext("chat", "Custom Menus"),
      :icon_dialog_custom_menus
    )
    |> add_window(
      window_open?(assigns.open_windows, "auto-respond"),
      "auto-respond",
      dgettext("chat", "Auto Respond"),
      :icon_dialog_auto_respond
    )
    |> add_window(
      window_open?(assigns.open_windows, "perform"),
      "perform",
      dgettext("chat", "Perform"),
      :icon_dialog_perform
    )
    |> add_window(
      window_open?(assigns.open_windows, "autojoin"),
      "autojoin",
      dgettext("chat", "Auto-Join"),
      :icon_dialog_autojoin
    )
    |> add_window(
      window_open?(assigns.open_windows, "notify-list"),
      "notify-list",
      dgettext("chat", "Notify List"),
      :icon_tab_notify
    )
    |> add_window(
      window_open?(assigns.open_windows, "nick-colors"),
      "nick-colors",
      dgettext("chat", "Nick Colors"),
      :icon_dialog_nick_colors
    )
    |> add_window(
      window_open?(assigns.open_windows, "ignore-list"),
      "ignore-list",
      dgettext("chat", "Ignore List"),
      :icon_dialog_ignore_list
    )
    |> add_window(
      window_open?(assigns.open_windows, "address-book"),
      "address-book",
      dgettext("chat", "Address Book"),
      :icon_dialog_address_book
    )
  end

  # The nine admin windows share one gate, so they enter the taskbar as a set
  # rather than as nine branches of the main pipeline.
  @admin_windows [
    {"admin-users", dgettext("chat", "Users"), :icon_community},
    {"admin-channels", dgettext("chat", "Channels"), :icon_channels},
    {"admin-server-settings", dgettext("chat", "Server Settings"), :icon_server},
    {"admin-audit-log", dgettext("chat", "Audit Log"), :icon_notepad},
    {"admin-motd", dgettext("chat", "MOTD"), :icon_notepad},
    {"admin-turn", dgettext("chat", "TURN"), :icon_websocket},
    {"admin-broadcast", dgettext("chat", "Broadcast"), :icon_megaphone},
    {"admin-danger-zone", dgettext("chat", "Danger Zone"), :icon_warning},
    {"admin-console", dgettext("chat", "Console"), :icon_dialog_admin_console}
  ]

  defp add_admin_windows(windows, %{is_admin: true} = assigns) do
    Enum.reduce(@admin_windows, windows, fn {id, label, icon_fn}, acc ->
      add_window(acc, window_open?(assigns.open_windows, id), id, label, icon_fn)
    end)
  end

  defp add_admin_windows(windows, _assigns), do: windows

  defp add_window(windows, condition, id, label, icon_fn, opts \\ [])

  defp add_window(windows, condition, id, label, icon_fn, opts)
       when condition not in [nil, false] do
    windows ++ [Map.merge(%{id: id, label: label, icon_fn: icon_fn}, Map.new(opts))]
  end

  defp add_window(windows, _condition, _id, _label, _icon_fn, _opts), do: windows

  defp mobile_window_testid(%{testid: testid}) when is_binary(testid), do: "#{testid}-mobile"
  defp mobile_window_testid(_window), do: nil

  defp window_open?(open_windows, id) when is_binary(id) do
    MapSet.member?(open_windows || MapSet.new(), id)
  end

  defp p2p_call_label(%{peer_nick: peer_nick}) when peer_nick not in [nil, ""] do
    dgettext("chat", "P2P: %{peer}", peer: peer_nick)
  end

  defp p2p_call_label(_p2p_session), do: dgettext("chat", "P2P Session")

  defp group_call_label(%{channel_name: channel_name}) when channel_name not in [nil, ""] do
    channel_name
  end

  defp group_call_label(_group_call), do: dgettext("group_call", "Group Call")
end
