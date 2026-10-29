defmodule RetroHexChatWeb.ChatLive.WindowRegistry do
  @moduledoc """
  Every window of the chat desktop, declared once.

  A window used to be described in five unconnected places: the markup that
  renders it, the set that decides whether the server owns its lifecycle, the
  map from opener event to id, the taskbar's hand-written pipeline, and the
  menus. Title and icon were written three times each, and nothing checked that
  the three agreed — so a window could be fully functional, focusable and
  cascading, and still have no taskbar button, with the whole test suite green.
  That is exactly how the runtime windows shipped without one.

  This module is the single declaration. Everything else derives:

    * `desktop_live.html.heex` spreads `attrs/1` onto `desktop_window` (title,
      icon, geometry), and draws a window whose island needs only the session
      in one line with `RetroHexChatWeb.ChatLive.RegisteredWindow`
    * `RetroHexChatWeb.ChatLive.Windows` takes `managed?/1` from here
    * `RetroHexChatWeb.ChatLive.AdminEvents` and `RetroHexChatWeb.ChatLive.WindowOpenEvents`
      take their opener maps from here
    * `RetroHexChatWeb.Components.UI.ChatTaskbar` builds its strip from here
    * the Start menu and the desktop folders build their Admin and System groups
      from here; their other groups come from `RetroHexChatWeb.Components.UI.AppGroups`

  `window_registry_test.exs` checks the template against this list: every
  window drawn exactly once, and every admin window's block gated on the role.

  ## Why this is a function and not a module attribute

  Labels are resolved by calling `windows/0`, never by reading a constant. A
  `dgettext` call evaluated inside a module attribute is executed *at compile
  time*, freezing whatever locale compiled the release — which is precisely
  what had happened to the admin taskbar buttons and the family group labels:
  they read English in all thirteen locales. Keeping the list behind a function
  is what makes a translated label possible at all.

  ## Conditions

  A window's visibility is declared, not coded, so the same declaration can be
  read by the markup and by the taskbar:

    * `:always` — rendered and listed unconditionally
    * `:open` — while its id is in `open_windows`
    * `:admin` — admin only, and open
    * `{:present, assign}` — while that assign is non-nil (a live call)
    * `{:present_and_open, assign}` — both
    * `:never` — not on the taskbar at all
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChatWeb.ChatLive.Components

  @type condition ::
          :always
          | :open
          | :admin
          | :never
          | {:present, atom()}
          | {:present_and_open, atom()}

  @type t :: %{
          id: String.t(),
          title: String.t(),
          icon: atom(),
          managed?: boolean(),
          pinned?: boolean(),
          render_when: condition(),
          taskbar_when: condition(),
          taskbar_label: String.t(),
          family: atom() | nil,
          opener: String.t() | nil,
          island: module() | nil,
          geometry: geometry()
        }

  @type geometry :: %{
          x: integer(),
          y: integer(),
          width: integer(),
          height: integer() | nil,
          min_width: integer(),
          min_height: integer()
        }

  @doc """
  Every window on the chat desktop, in the order the taskbar lists them.

  Order matters: the taskbar's family grouping takes the position of a family's
  first member, so reordering here reorders the strip.
  """
  @spec windows() :: [t()]
  def windows do
    core() ++
      tools() ++
      accessories() ++ automation() ++ settings() ++ account() ++ calls() ++ admin() ++ system()
  end

  @doc "One window by id, or nil."
  @spec fetch(String.t()) :: t() | nil
  def fetch(id), do: Enum.find(windows(), &(&1.id == id))

  @doc "The ids whose lifecycle the server owns — mounted only while open."
  @spec managed_ids() :: [String.t()]
  def managed_ids do
    for window <- windows(), window.managed?, do: window.id
  end

  @doc "Opener event name to window id, for every window an event opens."
  @spec openers() :: %{String.t() => String.t()}
  def openers do
    for window <- windows(), window.opener, into: %{}, do: {window.opener, window.id}
  end

  @doc """
  Opener event name to window id, split by gate: `:admin` for the windows only
  the admin role may open (`AdminEvents` checks it), `:plain` for the rest,
  which an event opens with no other work (`WindowOpenEvents`).
  """
  @spec openers(:admin | :plain) :: %{String.t() => String.t()}
  def openers(:admin), do: openers_where(&(&1.render_when == :admin))
  def openers(:plain), do: openers_where(&(&1.render_when != :admin))

  defp openers_where(filter) do
    for window <- windows(),
        window.opener,
        filter.(window),
        into: %{},
        do: {window.opener, window.id}
  end

  @doc """
  The windows a menu lists under one heading, as `{opener, title, icon}`:
  `:admin` is everything the admin role gates that is not filed under
  System, `:system` the System family. Every menu that lists them reads
  them here, so the Start menu and the desktop launchers cannot disagree.
  """
  @spec menu_entries(:admin | :system) :: [{String.t(), String.t(), atom()}]
  def menu_entries(:admin), do: entries(&(&1.render_when == :admin and &1.family != :system))
  def menu_entries(:system), do: entries(&(&1.family == :system))

  defp entries(filter) do
    for window <- windows(),
        window.opener,
        filter.(window),
        do: {window.opener, window.title, window.icon}
  end

  @doc "The ids an opener may only reach with the admin role."
  @spec admin_ids() :: [String.t()]
  def admin_ids do
    for window <- windows(), window.render_when == :admin, do: window.id
  end

  @doc """
  The attributes `desktop_window` needs, ready to be spread.

  Everything visual about a window travels from here, so the markup carries
  only what is genuinely unique to it: its body.
  """
  @spec attrs(String.t()) :: map()
  def attrs(id) do
    window = fetch(id) || raise ArgumentError, "no window registered as #{inspect(id)}"

    %{
      id: window.id,
      title: window.title,
      icon_name: window.icon,
      managed: window.managed?,
      pinned: window.pinned?,
      default_x: window.geometry.x,
      default_y: window.geometry.y,
      width: window.geometry.width,
      height: window.geometry.height,
      min_width: window.geometry.min_width,
      min_height: window.geometry.min_height
    }
  end

  @doc """
  Whether a condition holds, given what the desktop currently knows.

  `capabilities` carries `:admin?`, `:open_windows` and whichever assigns the
  `{:present, _}` conditions name.
  """
  @spec visible?(condition(), map()) :: boolean()
  def visible?(:always, _capabilities), do: true
  def visible?(:never, _capabilities), do: false
  def visible?(:open, _capabilities), do: true

  def visible?(:admin, capabilities), do: capabilities[:admin?] == true

  def visible?({:present, assign}, capabilities), do: present?(capabilities[assign])

  def visible?({:present_and_open, assign}, capabilities), do: present?(capabilities[assign])

  @doc """
  Whether `window` belongs on the taskbar right now.

  Combines the declared condition with whether the window is actually open,
  which is what `:open`, `:admin` and `{:present_and_open, _}` all additionally
  require.
  """
  @spec on_taskbar?(t(), map()) :: boolean()
  def on_taskbar?(%{taskbar_when: condition} = window, capabilities) do
    visible?(condition, capabilities) and open_enough?(condition, window, capabilities)
  end

  defp open_enough?(:open, window, capabilities), do: open?(window, capabilities)
  defp open_enough?(:admin, window, capabilities), do: open?(window, capabilities)

  defp open_enough?({:present_and_open, _assign}, window, capabilities) do
    open?(window, capabilities)
  end

  defp open_enough?(_condition, _window, _capabilities), do: true

  defp open?(window, capabilities) do
    MapSet.member?(capabilities[:open_windows] || MapSet.new(), window.id)
  end

  defp present?(nil), do: false
  defp present?(false), do: false
  defp present?(_value), do: true

  # ── The declarations ──────────────────────────────────

  defp core do
    [
      window("chat", dgettext("chat", "Chat"), :icon_chat,
        managed?: false,
        pinned?: true,
        render_when: :always,
        taskbar_when: :always,
        geometry: geometry(48, 24, 920, 580, 480, 320)
      ),
      window("url-catcher", dgettext("chat", "URL Catcher"), :icon_link,
        opener: "toggle_url_catcher",
        managed?: false,
        render_when: :always,
        taskbar_when: :always,
        geometry: geometry(80, 60, 640, 440, 420, 280)
      ),
      window("channel-list", dgettext("chat", "Channel List"), :icon_channels,
        managed?: false,
        render_when: :always,
        taskbar_when: :always,
        geometry: geometry(120, 70, 620, 480, 480, 320)
      ),
      window("mentions", dgettext("chat", "Mentions"), :icon_megaphone,
        geometry: geometry(160, 80, 620, 480, 420, 320)
      ),
      window("pinned", dgettext("chat", "Pinned"), :icon_btn_set_topic,
        geometry: geometry(170, 90, 620, 480, 420, 320)
      ),
      window("saved", dgettext("chat", "Saved Messages"), :icon_btn_star,
        geometry: geometry(180, 100, 620, 480, 420, 320)
      ),
      window("thread", dgettext("chat", "Thread"), :icon_chat,
        geometry: geometry(190, 110, 560, 520, 400, 360)
      ),
      window("events", dgettext("chat", "Events"), :icon_clock,
        geometry: geometry(200, 120, 560, 460, 400, 320)
      ),
      window("channel-central", dgettext("chat", "Channel Central"), :icon_dialog_channel_central,
        managed?: false,
        render_when: :always,
        taskbar_when: {:present, :cc_window_channel},
        geometry: geometry(140, 30, 640, 660, 500, 440)
      ),
      window("cheatsheet", dgettext("chat", "Keyboard Shortcuts"), :icon_dialog_cheatsheet,
        geometry: geometry(200, 60, 600, 500, 360, 320)
      )
    ]
  end

  defp tools do
    [
      window("address-book", dgettext("chat", "Address Book"), :icon_dialog_address_book,
        opener: "toggle_address_book",
        family: :contacts,
        geometry: geometry(100, 50, 640, 480, 480, 340)
      ),
      window("nick-colors", dgettext("chat", "Nick Colors"), :icon_dialog_nick_colors,
        island: Components.NickColorsDialog,
        opener: "open_nick_colors_dialog",
        family: :contacts,
        geometry: geometry(140, 90, 520, 440, 420, 320)
      ),
      window("ignore-list", dgettext("chat", "Ignore List"), :icon_dialog_ignore_list,
        island: Components.IgnoreListDialog,
        opener: "open_ignore_list_dialog",
        family: :contacts,
        geometry: geometry(170, 110, 560, 440, 440, 320)
      ),
      window("notify-list", dgettext("chat", "Notify List"), :icon_tab_notify,
        opener: "toggle_notify_list",
        family: :contacts,
        geometry: geometry(210, 140, 560, 520, 440, 360)
      ),
      window("highlight", dgettext("chat", "Highlight Words"), :icon_star,
        island: Components.HighlightDialog,
        opener: "open_highlight_dialog",
        geometry: geometry(160, 70, 520, 520, 400, 360)
      ),
      window("user-lookup", dgettext("chat", "User Lookup"), :icon_btn_search,
        geometry: geometry(240, 100, 500, 420, 340, 280)
      ),
      window("timers", dgettext("chat", "Timers"), :icon_btn_timers,
        geometry: geometry(120, 90, 720, 470, 520, 320)
      )
    ]
  end

  # The desktop's programs: managed, so closing one unmounts its island; a
  # drawing waits in the browser as a draft, and the radio stops playing.
  defp accessories do
    [
      window("paint", "Hex Paint", :icon_paint,
        island: Components.PaintWindow,
        opener: "open_paint",
        geometry: geometry(140, 60, 720, 560, 420, 420)
      ),
      window("ascii-art", dgettext("chat", "ASCII Art"), :icon_ascii_art,
        island: Components.AsciiArtWindow,
        opener: "open_ascii_art",
        geometry: geometry(180, 80, 760, 560, 420, 420)
      ),
      window("radio", "Hex Radio", :icon_radio,
        island: Components.RadioWindow,
        opener: "open_radio",
        geometry: geometry(200, 40, 440, 640, 340, 420)
      )
    ]
  end

  defp automation do
    [
      window("perform", dgettext("chat", "Perform"), :icon_dialog_perform,
        island: Components.PerformDialog,
        opener: "open_perform_dialog",
        family: :connect,
        geometry: geometry(190, 130, 620, 460, 480, 340)
      ),
      window("autojoin", dgettext("chat", "Auto-Join"), :icon_dialog_autojoin,
        island: Components.AutojoinDialog,
        opener: "open_autojoin_dialog",
        family: :connect,
        geometry: geometry(230, 160, 520, 420, 420, 320)
      ),
      window("auto-respond", dgettext("chat", "Auto Respond"), :icon_dialog_auto_respond,
        geometry: geometry(170, 120, 700, 440, 540, 320)
      ),
      window("alias", dgettext("chat", "Alias Editor"), :icon_dialog_alias,
        geometry: geometry(130, 100, 640, 460, 480, 320)
      ),
      window("custom-menus", dgettext("chat", "Custom Menus"), :icon_dialog_custom_menus,
        geometry: geometry(150, 110, 640, 480, 480, 340)
      )
    ]
  end

  defp settings do
    [
      window("sound-settings", dgettext("chat", "Sound Settings"), :icon_dialog_sound,
        geometry: geometry(140, 80, 620, 480, 520, 340)
      ),
      window("flood-protection", dgettext("chat", "Flood Protection"), :icon_dialog_flood,
        geometry: geometry(180, 60, 560, 440, 360, 360)
      )
    ]
  end

  defp account do
    [
      window("account", dgettext("chat", "Account"), :icon_status_user,
        family: :account,
        geometry: geometry(180, 40, 560, 620, 420, 380)
      ),
      window("trusted-terminals", dgettext("chat", "Trusted Terminals"), :icon_lock,
        opener: "open_trusted_terminals_dialog",
        family: :account,
        geometry: geometry(150, 60, 800, 620, 520, 380)
      ),
      window("profile", dgettext("chat", "Profile"), :icon_dialog_profile,
        family: :account,
        geometry: geometry(210, 60, 540, 560, 420, 400)
      ),
      window("away", dgettext("chat", "Away"), :icon_dialog_away,
        family: :account,
        geometry: geometry(240, 100, 480, 440, 400, 380)
      ),
      window("user-modes", dgettext("chat", "User Modes"), :icon_dialog_user_modes,
        family: :account,
        geometry: geometry(270, 130, 440, 380, 380, 340)
      )
    ]
  end

  defp calls do
    [
      window("arcade-games", dgettext("chat", "Arcade"), :icon_game_arcade,
        render_when: {:present_and_open, :arcade_session},
        taskbar_when: {:present_and_open, :arcade_session},
        geometry: geometry(80, 24, 1040, 660, 760, 520)
      )
    ]
  end

  defp admin do
    [
      window("admin-users", dgettext("chat", "Users"), :icon_community,
        island: Components.AdminUsersDialog,
        admin: "open_admin_users",
        family: :admin,
        geometry: geometry(150, 60, 680, 680, 520, 460)
      ),
      window("admin-channels", dgettext("chat", "Channels"), :icon_channels,
        island: Components.AdminChannelsDialog,
        admin: "open_admin_channels",
        family: :admin,
        geometry: geometry(160, 70, 680, 680, 520, 460)
      ),
      window("admin-server-settings", dgettext("chat", "Server Settings"), :icon_server,
        island: Components.AdminServerSettingsDialog,
        admin: "open_admin_server_settings",
        family: :admin,
        geometry: geometry(170, 80, 700, 700, 480, 420)
      ),
      window("admin-audit-log", dgettext("chat", "Audit Log"), :icon_notepad,
        island: Components.AdminAuditLogDialog,
        admin: "open_admin_audit_log",
        family: :admin,
        geometry: geometry(180, 90, 620, 600, 480, 420)
      ),
      window("admin-motd", dgettext("chat", "MOTD"), :icon_notepad,
        island: Components.AdminMotdDialog,
        admin: "open_admin_motd",
        family: :admin,
        geometry: geometry(190, 100, 600, 580, 480, 420)
      ),
      window("admin-turn", dgettext("chat", "TURN"), :icon_websocket,
        island: Components.AdminTurnDialog,
        admin: "open_admin_turn",
        family: :admin,
        geometry: geometry(200, 110, 640, 560, 480, 420)
      ),
      window("admin-broadcast", dgettext("chat", "Broadcast"), :icon_megaphone,
        island: Components.AdminBroadcastDialog,
        admin: "open_admin_broadcast",
        family: :admin,
        geometry: geometry(210, 120, 560, 560, 480, 420)
      ),
      window("admin-danger-zone", dgettext("chat", "Danger Zone"), :icon_warning,
        island: Components.AdminDangerZoneDialog,
        admin: "open_admin_danger_zone",
        family: :admin,
        geometry: geometry(220, 130, 600, 620, 480, 420)
      ),
      window("admin-console", dgettext("chat", "Console"), :icon_dialog_admin_console,
        island: Components.AdminConsoleDialog,
        admin: "open_admin_console",
        family: :admin,
        geometry: geometry(140, 50, 680, 680, 520, 460)
      ),
      window(
        "bot-management-dialog",
        dgettext("chat", "Bot Management"),
        :icon_btn_bot_management,
        admin: "open_bot_dialog",
        geometry: geometry(200, 80, 720, 660, 520, 460)
      ),
      window("server-emoji", dgettext("chat", "Server Emoji"), :icon_fmt_emoji,
        admin: "open_server_emoji_dialog",
        geometry: geometry(210, 130, 520, 460, 400, 320)
      )
    ]
  end

  # The runtime inspection windows. A family of their own, because opening
  # three of them at once is the normal way to use them — and twelve unrelated
  # buttons is exactly what families exist to prevent.
  defp system do
    [
      window("system-home", dgettext("chat", "System"), :icon_server,
        island: Components.SystemHomeDialog,
        admin: "open_system_home",
        family: :system,
        geometry: geometry(140, 60, 640, 560, 480, 360)
      ),
      window("system-app-info", dgettext("chat", "App Info"), :icon_hex_stone,
        island: Components.SystemAppInfoDialog,
        admin: "open_system_app_info",
        family: :system,
        geometry: geometry(170, 118, 600, 520, 480, 320)
      ),
      window("system-metrics", dgettext("chat", "Metrics"), :icon_chart_bars,
        island: Components.SystemMetricsDialog,
        admin: "open_system_metrics",
        family: :system,
        geometry: geometry(130, 50, 820, 580, 480, 320)
      ),
      window("system-oban", "Oban", :icon_status_signal,
        island: Components.SystemObanDialog,
        admin: "open_system_oban",
        family: :system,
        geometry: geometry(150, 68, 860, 600, 520, 360)
      ),
      window("system-processes", dgettext("chat", "Processes"), :icon_cpu,
        admin: "open_system_processes",
        family: :system,
        geometry: geometry(160, 80, 780, 520, 520, 320)
      ),
      window("system-applications", dgettext("chat", "Applications"), :icon_app_stack,
        admin: "open_system_applications",
        family: :system,
        geometry: geometry(280, 176, 780, 520, 520, 320)
      ),
      window("system-ets", dgettext("chat", "ETS Tables"), :icon_table_grid,
        admin: "open_system_ets",
        family: :system,
        geometry: geometry(250, 152, 780, 520, 520, 320)
      ),
      window("system-ports", dgettext("chat", "Ports"), :icon_plug,
        admin: "open_system_ports",
        family: :system,
        geometry: geometry(190, 104, 780, 520, 520, 320)
      ),
      window("system-sockets", dgettext("chat", "Sockets"), :icon_websocket,
        admin: "open_system_sockets",
        family: :system,
        geometry: geometry(220, 128, 780, 520, 520, 320)
      ),
      window("system-allocators", dgettext("chat", "Memory Allocators"), :icon_memory,
        admin: "open_system_allocators",
        family: :system,
        geometry: geometry(310, 200, 780, 520, 520, 320)
      ),
      window("system-os", dgettext("chat", "OS Data"), :icon_operating_system,
        island: Components.SystemOsDialog,
        admin: "open_system_os",
        family: :system,
        geometry: geometry(200, 70, 560, 540, 480, 320)
      ),
      window("system-database", dgettext("chat", "Database Stats"), :icon_postgres,
        island: Components.SystemDatabaseDialog,
        admin: "open_system_database",
        family: :system,
        geometry: geometry(230, 94, 760, 520, 480, 320)
      ),
      window("system-request-logger", dgettext("chat", "Live Log"), :icon_terminal,
        island: Components.SystemLogDialog,
        admin: "open_system_request_logger",
        family: :system,
        geometry: geometry(260, 142, 720, 480, 480, 320)
      )
    ]
  end

  # ── Construction ──────────────────────────────────────

  # `admin:` is shorthand for the shape every privileged window shares: opened
  # by an event, gated on the role, and listed on the taskbar under the same
  # condition. Spelling it out at nineteen call sites is what let one of them
  # silently disagree with the others.
  defp window(id, title, icon, opts) do
    admin_opener = Keyword.get(opts, :admin)
    condition = if admin_opener, do: :admin, else: Keyword.get(opts, :render_when, :open)

    %{
      id: id,
      title: title,
      icon: icon,
      managed?: Keyword.get(opts, :managed?, true),
      pinned?: Keyword.get(opts, :pinned?, false),
      render_when: condition,
      taskbar_when: Keyword.get(opts, :taskbar_when, condition),
      taskbar_label: Keyword.get(opts, :taskbar_label, title),
      family: Keyword.get(opts, :family),
      opener: admin_opener || Keyword.get(opts, :opener),
      island: Keyword.get(opts, :island),
      geometry: Keyword.fetch!(opts, :geometry)
    }
  end

  defp geometry(x, y, width, height, min_width, min_height) do
    %{x: x, y: y, width: width, height: height, min_width: min_width, min_height: min_height}
  end
end
