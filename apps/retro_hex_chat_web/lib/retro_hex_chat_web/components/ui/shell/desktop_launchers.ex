defmodule RetroHexChatWeb.Components.UI.DesktopLaunchers do
  @moduledoc """
  Desktop app groups: visible icons on the wallpaper plus the Windows-style
  launcher windows those icons open inside the chat desktop.

  The Start menu remains the canonical menu interaction. These launchers are a
  second surface for the same grouped app map: a visible desktop affordance for
  people who do not proactively open Start.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.ChatLive.WindowRegistry
  alias RetroHexChatWeb.Components.UI.LanguageMenu
  alias RetroHexChatWeb.Icons

  @screens [:chat, :connect, :landing, :help, :showcase]
  @app_screens [:chat, :connect]
  @connect_dialog_id "desktop-connect-required-dialog"

  attr :screen, :atom,
    required: true,
    values: @screens,
    doc: "which desktop the icons are rendered on"

  attr :is_admin, :boolean, default: false
  attr :p2p_active, :boolean, default: false
  attr :p2p_turn_available, :boolean, default: false
  attr :arcade_available, :boolean, default: false
  attr :windows, :list, default: []
  attr :current_path, :string, default: nil
  attr :language_return_to, :string, default: nil
  attr :connect_dialog_id, :string, default: @connect_dialog_id
  attr :on_action, :any, default: "toolbar_action"

  @spec desktop_launcher_icons(map()) :: Phoenix.LiveView.Rendered.t()
  def desktop_launcher_icons(assigns) do
    assigns = assign(assigns, :groups, launcher_groups(assigns))

    ~H"""
    <%= for group <- @groups do %>
      <.desktop_icon
        :if={desktop_window_icon?(@screen, group)}
        window={group.window_id}
        action={desktop_icon_action(@screen, group)}
        href={desktop_icon_href(@screen, group)}
        label={group.label}
        data-testid={"desktop-icon-#{group.id}"}
      >
        <:icon>{apply(Icons, group.icon_fn, [%{class: "h-8 w-8"}])}</:icon>
      </.desktop_icon>

      <button
        :if={desktop_click_target_icon?(@screen, group)}
        type="button"
        class="desktop-shortcut"
        data-desktop-click-target={desktop_click_target(@screen, group)}
        data-testid={"desktop-icon-#{group.id}"}
      >
        <span class="desktop-shortcut__icon inline-flex h-8 w-8 items-center justify-center">
          {apply(Icons, group.icon_fn, [%{class: "h-8 w-8"}])}
        </span>
        <span class="desktop-shortcut__label">{group.label}</span>
      </button>

      <button
        :if={!desktop_icon_available?(@screen, group)}
        type="button"
        class="desktop-shortcut"
        data-desktop-connect-required="true"
        data-desktop-connect-dialog={@connect_dialog_id}
        data-testid={"desktop-icon-#{group.id}"}
      >
        <span class="desktop-shortcut__icon inline-flex h-8 w-8 items-center justify-center">
          {apply(Icons, group.icon_fn, [%{class: "h-8 w-8"}])}
        </span>
        <span class="desktop-shortcut__label">{group.label}</span>
      </button>
    <% end %>
    """
  end

  attr :screen, :atom, required: true, values: @screens
  attr :is_admin, :boolean, default: false
  attr :p2p_active, :boolean, default: false
  attr :p2p_turn_available, :boolean, default: false
  attr :arcade_available, :boolean, default: false
  attr :windows, :list, default: []
  attr :current_path, :string, default: nil
  attr :language_return_to, :string, default: nil
  attr :on_action, :any, default: "toolbar_action"

  @spec desktop_launcher_windows(map()) :: Phoenix.LiveView.Rendered.t()
  def desktop_launcher_windows(assigns) do
    assigns =
      assign(
        assigns,
        :groups,
        launcher_window_groups(assigns)
      )

    ~H"""
    <.desktop_window
      :for={group <- @groups}
      id={group.window_id}
      title={group.label}
      open={false}
      default_x={group.default_x}
      default_y={group.default_y}
      width={500}
      height={330}
      min_width={320}
      min_height={220}
      body_class="desktop-launcher-window bg-white p-2"
      data-testid={"desktop-launcher-window-#{group.id}"}
    >
      <:icon>{apply(Icons, group.icon_fn, [%{class: "h-4 w-4"}])}</:icon>

      <div class="desktop-launcher-grid" data-testid={"desktop-launcher-grid-#{group.id}"}>
        <.launcher_item :for={item <- group.items} item={item} />
      </div>

      <:status>
        <.window_status_bar_field grow>
          {dngettext(
            "ui",
            "%{count} object",
            "%{count} objects",
            group.object_count,
            count: group.object_count
          )}
        </.window_status_bar_field>
      </:status>
    </.desktop_window>
    """
  end

  attr :screen, :atom, required: true, values: @screens
  attr :is_admin, :boolean, default: false
  attr :p2p_active, :boolean, default: false
  attr :p2p_turn_available, :boolean, default: false
  attr :arcade_available, :boolean, default: false
  attr :windows, :list, default: []
  attr :current_path, :string, default: nil
  attr :language_return_to, :string, default: nil
  attr :on_action, :any, default: "toolbar_action"

  @spec desktop_launcher_taskbar_buttons(map()) :: Phoenix.LiveView.Rendered.t()
  def desktop_launcher_taskbar_buttons(assigns) do
    assigns =
      assign(
        assigns,
        :groups,
        launcher_window_groups(assigns)
      )

    ~H"""
    <.taskbar_button
      :for={group <- @groups}
      window={group.window_id}
      label={group.label}
      class="desktop-taskbar__window-button"
      data-testid={"desktop-launcher-taskbar-#{group.id}"}
    >
      <:icon>{apply(Icons, group.icon_fn, [%{class: "h-4 w-4"}])}</:icon>
    </.taskbar_button>
    """
  end

  attr :id, :string, default: @connect_dialog_id

  @spec desktop_connect_required_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def desktop_connect_required_dialog(assigns) do
    ~H"""
    <div
      id={@id}
      data-desktop-connect-dialog
      data-state="closed"
      class="z-modal group/dialog relative hidden"
    >
      <button
        type="button"
        class="fixed inset-0 bg-black/30"
        data-desktop-connect-dialog-close
        aria-label={dgettext("ui", "Close")}
      >
      </button>

      <div
        class="fixed inset-0 flex items-center justify-center overflow-y-auto p-0 md:p-4"
        role="dialog"
        aria-modal="true"
        aria-labelledby={"#{@id}-title"}
        tabindex="0"
      >
        <div
          id={"#{@id}-surface"}
          class="flex w-full min-h-[100dvh] max-h-[100dvh] flex-col bg-surface p-[3px] shadow-retro-window md:min-h-0 md:max-h-[90dvh] md:max-w-sm"
        >
          <div class="shrink-0 bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
            <span class="shrink-0 flex items-center justify-center w-[16px] h-[16px]">
              <Icons.icon_connect class="w-4 h-4" />
            </span>
            <span id={"#{@id}-title"} class="text-xs font-bold text-white truncate select-none">
              {dgettext("dialogs", "Connect required")}
            </span>
            <button
              type="button"
              class="bg-surface shadow-retro-raised active:shadow-retro-sunken flex items-center justify-center shrink-0 ml-auto w-[16px] h-[14px]"
              data-desktop-connect-dialog-close
              aria-label={dgettext("ui", "Close")}
            >
              <Icons.icon_close_pixel class="w-[8px] h-[7px]" />
            </button>
          </div>

          <div class="flex-1 min-h-0 p-retro-12 overflow-y-auto">
            <div class="flex items-start gap-3">
              <Icons.icon_lock class="h-8 w-8 shrink-0" />
              <div class="space-y-2 text-xs leading-relaxed">
                <p class="font-bold text-text">
                  {dgettext("dialogs", "This app group needs a chat session.")}
                </p>
                <p class="text-muted-foreground">
                  {dgettext(
                    "dialogs",
                    "Connect first to use this desktop app folder. Help and Language remain available without a chat session."
                  )}
                </p>
              </div>
            </div>
          </div>

          <div class="shrink-0 flex justify-end gap-retro-4 px-retro-12 pb-retro-12">
            <button
              id={"#{@id}-ok"}
              type="button"
              class={classes([button_variant(%{}), "gap-retro-4"])}
              data-desktop-connect-dialog-close
            >
              <span class="inline-flex h-4 w-4 shrink-0 items-center justify-center">
                <Icons.icon_checkmark class="w-4 h-4" />
              </span>
              {dgettext("dialogs", "OK")}
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp launcher_groups(assigns) do
    cap = capabilities(assigns)

    [
      group(:view, dgettext("ui", "View"), :icon_channels, view_items(cap)),
      group(:tools, dgettext("ui", "Tools"), :icon_group_tools, tools_items(cap)),
      group(
        :automation,
        dgettext("ui", "Automation"),
        :icon_dialog_perform,
        automation_items(cap)
      ),
      group(:p2p, dgettext("ui", "P2P"), :icon_p2p, p2p_items(cap)),
      group(:games, dgettext("ui", "Games"), :icon_game_arcade, games_items(cap)),
      group(:account, dgettext("ui", "Account"), :icon_status_user, account_items(cap)),
      group(:admin, dgettext("ui", "Admin"), :icon_shield, admin_items(cap)),
      group(:system, dgettext("ui", "System"), :icon_server, system_items(cap)),
      group(:language, dgettext("ui", "Language"), :icon_globe, language_items(cap)),
      group(:help, dgettext("ui", "Help"), :icon_group_help, help_items(cap))
    ]
    |> Enum.reject(&privileged_group_hidden?(&1, cap))
    |> Enum.with_index()
    |> Enum.map(fn {group, index} ->
      group
      |> Map.put(:window_id, "desktop-launcher-#{group.id}")
      |> Map.put(:default_x, 72 + rem(index, 4) * 28)
      |> Map.put(:default_y, 48 + div(index, 4) * 28)
      |> Map.put(:object_count, object_count(group.items))
    end)
  end

  defp launcher_window_groups(%{screen: :chat} = assigns), do: launcher_groups(assigns)
  defp launcher_window_groups(%{screen: :connect}), do: []

  defp launcher_window_groups(assigns) do
    assigns
    |> launcher_groups()
    |> Enum.filter(&(&1.id in [:language, :help]))
  end

  defp desktop_icon_available?(:chat, _group), do: true
  defp desktop_icon_available?(_screen, %{id: id}) when id in [:language, :help], do: true
  defp desktop_icon_available?(_screen, _group), do: false

  defp desktop_window_icon?(screen, group),
    do: desktop_icon_available?(screen, group) and not desktop_click_target_icon?(screen, group)

  defp desktop_click_target_icon?(:connect, %{id: :language}), do: true
  defp desktop_click_target_icon?(_screen, _group), do: false

  defp desktop_click_target(:connect, %{id: :language}),
    do: ~s(#menubar [data-testid="language-menu-trigger"])

  defp desktop_icon_action(:connect, %{id: :help}), do: "help_topics"
  defp desktop_icon_action(_screen, _group), do: nil

  defp desktop_icon_href(:connect, %{id: :help}), do: "/chat/help"
  defp desktop_icon_href(_screen, _group), do: nil

  defp capabilities(assigns) do
    screen = assigns.screen
    chat? = screen == :chat
    p2p_active? = chat? and assigns.p2p_active

    %{
      screen: screen,
      chat?: chat?,
      help?: screen == :help,
      p2p?: p2p_active?,
      p2p_idle?: chat? and not p2p_active?,
      p2p_turn_available?: assigns.p2p_turn_available,
      arcade_available?: chat? and assigns.arcade_available,
      admin?: chat? and assigns.is_admin,
      current_path: assigns.current_path,
      language_return_to: assigns.language_return_to,
      on_action: assigns.on_action
    }
  end

  defp group(id, label, icon_fn, items),
    do: %{id: id, label: label, icon_fn: icon_fn, items: items}

  defp privileged_group_hidden?(%{id: id}, cap) when id in [:admin, :system], do: !cap.admin?
  defp privileged_group_hidden?(_group, _cap), do: false

  defp object_count(items), do: Enum.count(items, &(&1.kind != :separator))

  defp view_items(cap) do
    [
      action(
        cap,
        "toggle_conversations",
        dgettext("ui", "Toggle Conversations"),
        :icon_btn_toggle_conversations,
        disabled: !cap.chat?
      ),
      action(cap, "toggle_nicklist", dgettext("ui", "Toggle Nicklist"), :icon_btn_toggle_nicklist,
        disabled: !cap.chat?
      ),
      action(
        cap,
        "toggle_strip_formatting",
        dgettext("chat", "Strip Formatting"),
        :icon_fmt_color,
        disabled: !cap.chat?
      ),
      separator(),
      action(cap, "clear_window", dgettext("ui", "Clear Window"), :icon_btn_remove,
        disabled: !cap.chat?
      ),
      copy_item(disabled: !cap.chat?),
      action(cap, "toggle_search", dgettext("ui", "Find"), :icon_btn_find, disabled: !cap.chat?),
      separator(),
      action(cap, "help_nav_tab", dgettext("help", "Contents"), :icon_notepad,
        disabled: !cap.help?,
        on_action: "help_nav_tab",
        value_tab: "contents",
        testid: "desktop-launcher-item-help-contents"
      ),
      action(cap, "help_nav_tab", dgettext("help", "Index"), :icon_btn_channel_list,
        disabled: !cap.help?,
        on_action: "help_nav_tab",
        value_tab: "index",
        testid: "desktop-launcher-item-help-index"
      ),
      action(cap, "help_nav_tab", dgettext("help", "Search"), :icon_btn_search,
        disabled: !cap.help?,
        on_action: "help_nav_tab",
        value_tab: "search",
        testid: "desktop-launcher-item-help-search"
      )
    ]
  end

  defp tools_items(cap) do
    [
      window("address-book", dgettext("ui", "Address Book"), :icon_btn_address_book,
        disabled: !cap.chat?
      ),
      window("notify-list", dgettext("ui", "Notify List"), :icon_tab_notify,
        disabled: !cap.chat?
      ),
      window("ignore-list", dgettext("ui", "Ignore List"), :icon_btn_ignore_list,
        disabled: !cap.chat?
      ),
      window("highlight", dgettext("ui", "Highlight Words"), :icon_btn_highlight_words,
        disabled: !cap.chat?
      ),
      window("user-lookup", dgettext("ui", "User Lookup"), :icon_btn_search,
        disabled: !cap.chat?
      ),
      window("url-catcher", dgettext("ui", "URL Catcher"), :icon_btn_url_catcher,
        disabled: !cap.chat?
      ),
      action(cap, "toggle_channel_list", dgettext("ui", "Channel List"), :icon_btn_channel_list,
        disabled: !cap.chat?
      ),
      action(
        cap,
        "open_channel_central",
        dgettext("ui", "Channel Central"),
        :icon_btn_channel_central,
        disabled: !cap.chat?
      ),
      separator(),
      window("nick-colors", dgettext("ui", "Nick Colors"), :icon_btn_nick_colors,
        disabled: !cap.chat?
      ),
      window("sound-settings", dgettext("ui", "Sounds"), :icon_btn_sounds, disabled: !cap.chat?),
      window("flood-protection", dgettext("ui", "Flood Protection"), :icon_btn_flood_protection,
        disabled: !cap.chat?
      )
    ]
  end

  defp automation_items(cap) do
    [
      window("perform", dgettext("ui", "Perform"), :icon_btn_perform, disabled: !cap.chat?),
      window("autojoin", dgettext("ui", "Auto-Join"), :icon_btn_autojoin, disabled: !cap.chat?),
      window("auto-respond", dgettext("ui", "Auto Respond"), :icon_btn_auto_respond,
        disabled: !cap.chat?
      ),
      window("alias", dgettext("ui", "Alias Editor"), :icon_btn_alias_editor,
        disabled: !cap.chat?
      ),
      window("custom-menus", dgettext("ui", "Custom Menus"), :icon_btn_custom_menus,
        disabled: !cap.chat?
      ),
      window("timers", dgettext("ui", "Timers"), :icon_btn_timers, disabled: !cap.chat?)
    ]
  end

  defp p2p_items(cap) do
    [
      action(
        cap,
        "p2p_how_to_start",
        dgettext("ui", "Start a P2P Session..."),
        :icon_protocol_p2p_compact,
        disabled: !cap.p2p_idle?
      ),
      action(cap, "p2p_start_audio", dgettext("ui", "Start Audio Call"), :icon_microphone,
        disabled: !cap.p2p?
      ),
      action(cap, "p2p_start_video", dgettext("ui", "Start Video Call"), :icon_camera,
        disabled: !cap.p2p?
      ),
      action(cap, "p2p_console_select", dgettext("ui", "Send a File..."), :icon_file_send,
        disabled: !cap.p2p?,
        value_section: "files",
        testid: "desktop-launcher-item-p2p-files"
      ),
      action(cap, "p2p_console_select", dgettext("ui", "Play a Game..."), :icon_game_arcade,
        disabled: !cap.p2p?,
        value_section: "games",
        testid: "desktop-launcher-item-p2p-games"
      ),
      action(cap, "p2p_console_select", dgettext("ui", "P2P Stats"), :icon_status_signal,
        disabled: !cap.p2p?,
        value_section: "stats",
        testid: "desktop-launcher-item-p2p-stats"
      ),
      action(cap, "p2p_toggle_privacy", dgettext("ui", "Toggle Privacy Mode"), :icon_lock,
        disabled: !cap.p2p? or !cap.p2p_turn_available?
      ),
      separator(),
      action(cap, "p2p_end_session", dgettext("ui", "End P2P Session"), :icon_btn_disconnect,
        disabled: !cap.p2p?
      )
    ]
  end

  defp games_items(cap) do
    [
      action(cap, "open_retro_games", dgettext("ui", "Retro Games"), :icon_game_pong,
        disabled: !cap.chat?,
        testid: "desktop-launcher-item-retro-games"
      ),
      action(cap, "open_arcade", dgettext("ui", "Arcade..."), :icon_game_arcade,
        disabled: !cap.chat? or !cap.arcade_available?
      )
    ]
  end

  defp account_items(cap) do
    [
      action(cap, "open_account_register", dgettext("ui", "Register Nickname..."), :icon_lock,
        disabled: !cap.chat?
      ),
      action(cap, "open_account_identify", dgettext("ui", "Identify..."), :icon_status_user,
        disabled: !cap.chat?
      ),
      separator(),
      action(cap, "open_account_dialog", dgettext("ui", "Account"), :icon_status_user,
        disabled: !cap.chat?
      ),
      action(cap, "open_profile_dialog", dgettext("ui", "Profile"), :icon_btn_profile,
        disabled: !cap.chat?
      ),
      action(cap, "open_away_dialog", dgettext("ui", "Away"), :icon_btn_away,
        disabled: !cap.chat?
      ),
      action(cap, "open_user_modes_dialog", dgettext("ui", "User Modes"), :icon_btn_user_modes,
        disabled: !cap.chat?
      ),
      action(
        cap,
        "open_trusted_terminals_dialog",
        dgettext("ui", "Trusted Terminals"),
        :icon_lock,
        disabled: !cap.chat?
      ),
      separator(),
      action(cap, "account_info", dgettext("ui", "Account Info"), :icon_tab_status,
        disabled: !cap.chat?
      )
    ]
  end

  defp admin_items(cap) do
    for {action, label, icon_fn} <- admin_entries() do
      action(cap, action, label, icon_fn, disabled: !cap.admin?)
    end
  end

  defp system_items(cap) do
    for {action, label, icon_fn} <- system_entries() do
      action(cap, action, label, icon_fn, disabled: !cap.admin?)
    end
  end

  defp language_items(cap) do
    Enum.map(locales(cap), fn locale ->
      link(locale.href, locale.label, :icon_globe,
        icon_kind: :flag,
        locale: locale.code,
        hreflang: locale.bcp47,
        testid: "desktop-launcher-item-language-#{locale.code}"
      )
    end)
  end

  defp help_items(cap) do
    [
      help_topics_item(cap),
      window("cheatsheet", dgettext("ui", "Shortcut Cheatsheet"), :icon_dialog_cheatsheet,
        disabled: !cap.chat?
      ),
      action(cap, "show_motd", dgettext("ui", "Message of the Day"), :icon_notepad,
        disabled: !cap.chat?
      ),
      separator(),
      link("https://github.com/rodrigomarchi/retro_hex_chat", "GitHub", :icon_code,
        target: "_blank",
        rel: "noopener",
        testid: "desktop-launcher-item-github"
      ),
      link(
        "https://github.com/rodrigomarchi/retro_hex_chat/blob/main/LICENSE",
        dgettext("landing", "License (MIT)"),
        :icon_legal,
        target: "_blank",
        rel: "noopener",
        testid: "desktop-launcher-item-license"
      ),
      separator(),
      about_item(cap)
    ]
  end

  defp help_topics_item(%{screen: :help}) do
    window("help", dgettext("ui", "Help Topics"), :icon_btn_help_topics,
      testid: "desktop-launcher-item-help_topics"
    )
  end

  defp help_topics_item(%{screen: screen} = cap) when screen in [:chat, :connect] do
    action(cap, "help_topics", dgettext("ui", "Help Topics"), :icon_btn_help_topics,
      on_action: "help_topics",
      testid: "desktop-launcher-item-help_topics"
    )
  end

  defp help_topics_item(_cap) do
    link("/chat/help", dgettext("ui", "Help Topics"), :icon_btn_help_topics,
      testid: "desktop-launcher-item-help_topics"
    )
  end

  defp about_item(%{screen: :landing}) do
    window("about", dgettext("ui", "About RetroHexChat"), :icon_dialog_about,
      testid: "desktop-launcher-item-show_about"
    )
  end

  defp about_item(_cap) do
    modal("about-dialog", dgettext("ui", "About RetroHexChat"), :icon_dialog_about,
      testid: "desktop-launcher-item-show_about"
    )
  end

  defp locales(%{screen: screen} = cap) when screen in @app_screens do
    LanguageMenu.locale_links(:app, nil, cap.language_return_to || default_return_to(screen))
  end

  defp locales(cap), do: LanguageMenu.locale_links(:public, cap.current_path, nil)

  defp default_return_to(:chat), do: "/chat"
  defp default_return_to(:connect), do: "/connect"

  defp admin_entries, do: menu_entries(&(&1.family == :admin or &1.id == "bot-management-dialog"))
  defp system_entries, do: menu_entries(&(&1.family == :system))

  defp menu_entries(filter) do
    for window <- WindowRegistry.windows(),
        window.opener,
        filter.(window),
        do: {window.opener, window.title, window.icon}
  end

  defp window(id, label, icon_fn, opts) do
    %{
      kind: :window,
      window: id,
      label: label,
      icon_fn: icon_fn,
      disabled: Keyword.get(opts, :disabled, false),
      testid: Keyword.get(opts, :testid, "desktop-launcher-item-#{id}")
    }
  end

  defp action(cap, action, label, icon_fn, opts) do
    %{
      kind: :action,
      action: action,
      on_action: Keyword.get(opts, :on_action, cap.on_action),
      label: label,
      icon_fn: icon_fn,
      disabled: Keyword.get(opts, :disabled, false),
      testid: Keyword.get(opts, :testid, "desktop-launcher-item-#{action}"),
      value_section: Keyword.get(opts, :value_section),
      value_tab: Keyword.get(opts, :value_tab)
    }
  end

  defp link(href, label, icon_fn, opts) do
    %{
      kind: :link,
      href: href,
      label: label,
      icon_fn: icon_fn,
      icon_kind: Keyword.get(opts, :icon_kind, :icon),
      locale: Keyword.get(opts, :locale),
      hreflang: Keyword.get(opts, :hreflang),
      target: Keyword.get(opts, :target),
      rel: Keyword.get(opts, :rel),
      class: Keyword.get(opts, :class),
      disabled: Keyword.get(opts, :disabled, false),
      testid: Keyword.fetch!(opts, :testid)
    }
  end

  defp copy_item(opts),
    do: %{
      kind: :copy,
      label: dgettext("ui", "Copy"),
      icon_fn: :icon_copy,
      disabled: Keyword.get(opts, :disabled, false),
      testid: "desktop-launcher-item-copy_selection"
    }

  defp modal(id, label, icon_fn, opts) do
    %{
      kind: :modal,
      modal_id: id,
      label: label,
      icon_fn: icon_fn,
      testid: Keyword.fetch!(opts, :testid),
      disabled: Keyword.get(opts, :disabled, false)
    }
  end

  defp separator, do: %{kind: :separator}

  attr :item, :map, required: true

  defp launcher_item(%{item: %{kind: :separator}} = assigns) do
    ~H"""
    <div class="desktop-launcher-separator" role="presentation"></div>
    """
  end

  defp launcher_item(%{item: %{kind: :window}} = assigns) do
    assigns = assign_item_class(assigns)

    ~H"""
    <button
      type="button"
      class={@item_class}
      disabled={@item.disabled}
      aria-disabled={@item.disabled && "true"}
      data-window-open={!@item.disabled && @item.window}
      data-testid={@item.testid}
    >
      <.launcher_item_icon item={@item} class="h-8 w-8" />
      <span class="desktop-launcher-item__label">{@item.label}</span>
    </button>
    """
  end

  defp launcher_item(%{item: %{kind: :action}} = assigns) do
    assigns = assign_item_class(assigns)

    ~H"""
    <button
      type="button"
      class={@item_class}
      disabled={@item.disabled}
      aria-disabled={@item.disabled && "true"}
      phx-click={!@item.disabled && @item.on_action}
      phx-value-action={!@item.disabled && @item.action}
      phx-value-section={!@item.disabled && @item.value_section}
      phx-value-tab={!@item.disabled && @item.value_tab}
      data-testid={@item.testid}
    >
      <.launcher_item_icon item={@item} class="h-8 w-8" />
      <span class="desktop-launcher-item__label">{@item.label}</span>
    </button>
    """
  end

  defp launcher_item(%{item: %{kind: :link, disabled: true}} = assigns) do
    assigns = assign_item_class(assigns)

    ~H"""
    <button
      type="button"
      class={@item_class}
      disabled
      aria-disabled="true"
      data-testid={@item.testid}
    >
      <.launcher_item_icon item={@item} class="h-8 w-8" />
      <span class="desktop-launcher-item__label">{@item.label}</span>
    </button>
    """
  end

  defp launcher_item(%{item: %{kind: :link}} = assigns) do
    assigns = assign_item_class(assigns)

    ~H"""
    <.link
      href={@item.href}
      class={@item_class}
      target={@item.target}
      rel={@item.rel}
      hreflang={@item.hreflang}
      data-locale={@item.locale}
      data-testid={@item.testid}
    >
      <.launcher_item_icon item={@item} class="h-8 w-8" />
      <span class="desktop-launcher-item__label">{@item.label}</span>
    </.link>
    """
  end

  defp launcher_item(%{item: %{kind: :copy}} = assigns) do
    assigns = assign_item_class(assigns)

    ~H"""
    <button
      type="button"
      class={classes([@item_class, !@item.disabled && "menubar-copy-disabled"])}
      disabled={@item.disabled}
      aria-disabled="true"
      data-menubar-copy-selection={!@item.disabled && "true"}
      data-copy-disabled="true"
      data-testid={@item.testid}
    >
      <.launcher_item_icon item={@item} class="h-8 w-8" />
      <span class="desktop-launcher-item__label">{@item.label}</span>
    </button>
    """
  end

  defp launcher_item(%{item: %{kind: :modal}} = assigns) do
    assigns = assign_item_class(assigns)

    ~H"""
    <button
      type="button"
      class={@item_class}
      disabled={@item.disabled}
      aria-disabled={@item.disabled && "true"}
      phx-click={!@item.disabled && show_modal(@item.modal_id)}
      data-testid={@item.testid}
    >
      <.launcher_item_icon item={@item} class="h-8 w-8" />
      <span class="desktop-launcher-item__label">{@item.label}</span>
    </button>
    """
  end

  defp assign_item_class(assigns) do
    item = assigns.item

    assign(assigns, :item_class, [
      "desktop-launcher-item",
      item.kind == :link && "text-text no-underline",
      item[:class],
      item[:disabled] && "desktop-launcher-item--disabled"
    ])
  end

  attr :item, :map, required: true
  attr :class, :any, default: nil

  defp launcher_item_icon(%{item: %{icon_kind: :flag}} = assigns) do
    ~H"""
    <span class="desktop-launcher-item__icon inline-flex h-8 w-8 items-center justify-center">
      <Icons.flag_icon locale={@item.locale} class={@class} />
    </span>
    """
  end

  defp launcher_item_icon(assigns) do
    ~H"""
    <span class="desktop-launcher-item__icon inline-flex h-8 w-8 items-center justify-center">
      {apply(Icons, @item.icon_fn, [%{class: @class}])}
    </span>
    """
  end
end
