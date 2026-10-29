defmodule RetroHexChatWeb.Components.UI.DesktopLaunchers do
  @moduledoc """
  Desktop app groups: visible icons on the wallpaper plus the Windows-style
  launcher windows those icons open inside the chat desktop.

  The Start menu remains the canonical menu interaction. These launchers are a
  second surface for the same grouped app map: a visible desktop affordance for
  people who do not proactively open Start.

  A visitor's desk also carries the site itself, down its right edge: an icon
  per page of the site and the site's About (`desktop_site_icons/1`), where a
  member keeps the pages in the About this site folder. The home's two files,
  README.txt and the Trash, close a visitor's app column.

  ## Folders inside folders

  A folder may hold folders (`folder/6`, an item of kind `:folder`), to any
  depth. Each folder has a window of its own, drawn beside its parent's, and
  shows its items either as icons or, `view: :cards`, as screenshot cards. The
  Start menu walks the same tree (`StartMenuApp`), a submenu per folder, so a
  feature that groups its entries this way gets the desktop folders, their
  windows, their taskbar buttons and the menu at once. The game catalogues
  (`catalogues/0`) are the first to: Retro Games and the Arcade hold a folder
  per category, and each category holds its games' cards.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button, only: [button: 1]
  import RetroHexChatWeb.Components.UI.ToolButton

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.ChatLive.WindowRegistry
  alias RetroHexChatWeb.Components.UI.AppGroups
  alias RetroHexChatWeb.Components.UI.Landing.GameCards
  alias RetroHexChatWeb.Components.UI.LanguageMenu
  alias RetroHexChatWeb.Components.UI.Site.DesktopFiles
  alias RetroHexChatWeb.Components.UI.Site.Document
  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Icons.Registry
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.Site.About

  @screens [:chat, :showcase]
  @connect_dialog_id "desktop-connect-required-dialog"

  # Each catalogue and the desktop folder its categories live in.
  @catalogues [multiplayer: :games, arcade: :arcade]

  attr :screen, :atom,
    required: true,
    values: @screens,
    doc: "which desktop the icons are rendered on"

  attr :is_admin, :boolean, default: false
  attr :windows, :list, default: []
  attr :current_path, :string, default: nil
  attr :language_return_to, :string, default: nil
  attr :connect_dialog_id, :string, default: @connect_dialog_id
  attr :on_action, :any, default: "toolbar_action"

  attr :visitor, :boolean,
    default: false,
    doc: """
    a reader without an account: the site's pages have icons of their own
    (`desktop_site_icons/1`) instead of the About this site folder, and the
    home's two files close the column
    """

  @spec desktop_launcher_icons(map()) :: Phoenix.LiveView.Rendered.t()
  def desktop_launcher_icons(assigns) do
    groups = launcher_groups(assigns)

    items =
      if assigns.visitor,
        do: Enum.map(Enum.reject(groups, &(&1.id == :site)), &{:group, &1}) ++ desktop_files(),
        else: Enum.map(groups, &{:group, &1})

    assigns = assign(assigns, items: items, chat?: assigns.screen == :chat)

    ~H"""
    <.launcher_shortcut
      :for={item <- @items}
      item={item}
      screen={@screen}
      chat?={@chat?}
      connect_dialog_id={@connect_dialog_id}
    />
    """
  end

  attr :connect_dialog_id, :string, default: @connect_dialog_id

  @doc """
  The site on a visitor's desk: an icon per page, in menu order — the home's
  being the Welcome a visitor's chat opens behind — and the site's About. A
  column of its own, down the desk's right edge, so the app's icons keep theirs.
  """
  @spec desktop_site_icons(map()) :: Phoenix.LiveView.Rendered.t()
  def desktop_site_icons(assigns) do
    assigns = assign(assigns, :items, site_shortcuts())

    ~H"""
    <.launcher_shortcut
      :for={item <- @items}
      item={item}
      screen={:chat}
      chat?={true}
      connect_dialog_id={@connect_dialog_id}
    />
    """
  end

  # One desktop icon, in whichever shape the item takes: a page of the site, a
  # window it opens, a file it shows, the folder it opens, or the closed door
  # that says a chat session is what is missing.
  attr :item, :any, required: true
  attr :screen, :atom, required: true
  attr :chat?, :boolean, required: true
  attr :connect_dialog_id, :string, required: true

  # A page of the site: double-clicked, the desktop asks for it (`open_page`,
  # `Site.Documents`), and its windows open over the chat.
  defp launcher_shortcut(%{item: {:page, page}} = assigns) do
    assigns = assign(assigns, :page, page)

    ~H"""
    <.desktop_icon
      window={Atom.to_string(@page.page)}
      action="open_page"
      label={@page.title}
      data-testid={"desktop-icon-page-#{@page.page}"}
    >
      <:icon>{apply(Icons, @page.icon, [%{class: "h-8 w-8"}])}</:icon>
    </.desktop_icon>
    """
  end

  defp launcher_shortcut(%{item: {:window, window}} = assigns) do
    assigns = assign(assigns, :window, window)

    ~H"""
    <.desktop_icon
      window={@window.id}
      label={@window.label}
      data-testid={"desktop-icon-#{@window.id}"}
    >
      <:icon>{apply(Icons, @window.icon_fn, [%{class: "h-8 w-8"}])}</:icon>
    </.desktop_icon>
    """
  end

  # A file on the desk opens as a popup of its own (`desktop.js`).
  defp launcher_shortcut(%{item: {:file, file}} = assigns) do
    assigns = assign(assigns, :file, file)

    ~H"""
    <.desktop_icon
      label={@file.label}
      data-show-target={"#" <> @file.popup}
      data-testid={"desktop-icon-#{@file.popup}"}
    >
      <:icon>{apply(Icons, @file.icon_fn, [%{class: "h-8 w-8"}])}</:icon>
    </.desktop_icon>
    """
  end

  defp launcher_shortcut(%{item: {:group, group}} = assigns) do
    assigns = assign(assigns, :group, group)

    ~H"""
    <.desktop_icon
      :if={desktop_icon_available?(@screen, @group)}
      window={@group.window_id}
      label={@group.label}
      data-testid={"desktop-icon-#{@group.id}"}
    >
      <:icon>{apply(Icons, @group.icon_fn, [%{class: "h-8 w-8"}])}</:icon>
    </.desktop_icon>

    <.desktop_icon
      :if={!desktop_icon_available?(@screen, @group)}
      label={@group.label}
      data-desktop-connect-required="true"
      data-desktop-connect-dialog={@connect_dialog_id}
      data-testid={"desktop-icon-#{@group.id}"}
    >
      <:icon>{apply(Icons, @group.icon_fn, [%{class: "h-8 w-8"}])}</:icon>
    </.desktop_icon>
    """
  end

  attr :screen, :atom, required: true, values: @screens
  attr :is_admin, :boolean, default: false
  attr :windows, :list, default: []
  attr :current_path, :string, default: nil
  attr :language_return_to, :string, default: nil
  attr :on_action, :any, default: "toolbar_action"

  attr :help_open, :boolean,
    default: false,
    doc: "the help viewer's window is open, so its tabs are live"

  @spec desktop_launcher_windows(map()) :: Phoenix.LiveView.Rendered.t()
  def desktop_launcher_windows(assigns) do
    assigns = assign(assigns, :folders, folder_windows(assigns))

    ~H"""
    <.desktop_window
      :for={folder <- @folders}
      id={folder.window_id}
      title={folder.label}
      open={false}
      default_x={folder.default_x}
      default_y={folder.default_y}
      width={if folder.view == :cards, do: 660, else: 500}
      height={if folder.view == :cards, do: 460, else: 330}
      min_width={320}
      min_height={220}
      body_class="desktop-launcher-window bg-white p-2"
      data-testid={"desktop-launcher-window-#{folder_key(folder)}"}
    >
      <:icon>{apply(Icons, folder.icon_fn, [%{class: "h-4 w-4"}])}</:icon>

      <div
        :if={folder.view == :icons}
        class="desktop-launcher-grid"
        data-testid={"desktop-launcher-grid-#{folder_key(folder)}"}
      >
        <.launcher_item :for={item <- folder.items} item={item} />
      </div>

      <div
        :if={folder.view == :cards}
        class="desktop-launcher-cards"
        data-testid={"desktop-launcher-grid-#{folder_key(folder)}"}
      >
        <GameCards.game_card
          :for={item <- folder.items}
          game={item.game}
          path={item.path}
          testid={item.testid}
        />
      </div>

      <:status>
        <.window_status_bar_field grow>
          {dngettext(
            "ui",
            "%{count} object",
            "%{count} objects",
            object_count(folder.items),
            count: object_count(folder.items)
          )}
        </.window_status_bar_field>
      </:status>
    </.desktop_window>
    """
  end

  @doc """
  The window a catalogue category opens in, by its catalogue and category:
  `desktop-launcher-arcade-fps`. The Start menu opens the same windows, and
  the Arcade goes back to one when its game is left.
  """
  @spec category_window_id(GameCatalog.kind(), GameCatalog.category()) :: String.t()
  def category_window_id(kind, category),
    do: "desktop-launcher-#{Keyword.fetch!(@catalogues, kind)}-#{category}"

  @doc "The desktop folder a catalogue's categories live in: `desktop-launcher-arcade`."
  @spec catalogue_window_id(GameCatalog.kind()) :: String.t()
  def catalogue_window_id(kind), do: "desktop-launcher-#{Keyword.fetch!(@catalogues, kind)}"

  @doc """
  The two game catalogues as desktop folders: Retro Games and the Arcade, each
  holding a folder per category (`GameCatalog.groups/1`), each of those
  holding its games as cards. The desktop's folders and the Start menu's
  Games group both read these.
  """
  @spec catalogues() :: [map()]
  def catalogues do
    for {kind, id} <- @catalogues do
      categories =
        for group <- GameCatalog.groups(kind) do
          folder(
            category_window_id(kind, group.category),
            group.category,
            group.name,
            group.icon_fn,
            Enum.map(group.games, &game_card(kind, &1)),
            view: :cards
          )
        end

      %{
        id: id,
        label: catalogue_label(kind),
        icon_fn: catalogue_icon(kind),
        window_id: catalogue_window_id(kind),
        view: :icons,
        items: categories
      }
    end
  end

  defp catalogue_label(:multiplayer), do: dgettext("ui", "Retro Games")
  defp catalogue_label(:arcade), do: dgettext("ui", "Arcade")

  defp catalogue_icon(:multiplayer), do: :icon_game_pong
  defp catalogue_icon(:arcade), do: :icon_game_arcade

  # A Retro Game opens its home over the chat — how to play, who is playing,
  # who is winning — and the game itself opens from there. An arcade game
  # opens the Arcade on its sheet, which asks a visitor for an account.
  defp game_card(:multiplayer, game),
    do: card(game, Paths.game_page_path(game.id), "desktop-launcher-item-game-#{game.id}")

  defp game_card(:arcade, game),
    do: card(game, Paths.chat_arcade_path(game.id), "arcade-game-#{game.id}")

  attr :screen, :atom, required: true, values: @screens
  attr :is_admin, :boolean, default: false
  attr :windows, :list, default: []
  attr :current_path, :string, default: nil
  attr :language_return_to, :string, default: nil
  attr :on_action, :any, default: "toolbar_action"

  @spec desktop_launcher_taskbar_buttons(map()) :: Phoenix.LiveView.Rendered.t()
  def desktop_launcher_taskbar_buttons(assigns) do
    assigns = assign(assigns, :folders, folder_windows(assigns))

    ~H"""
    <.taskbar_button
      :for={folder <- @folders}
      window={folder.window_id}
      label={folder.label}
      class="desktop-taskbar__window-button"
      data-testid={"desktop-launcher-taskbar-#{folder_key(folder)}"}
    >
      <:icon>{apply(Icons, folder.icon_fn, [%{class: "h-4 w-4"}])}</:icon>
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
      ></button>

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
            <.tool_button
              label={dgettext("ui", "Close")}
              size="title"
              class="ml-auto"
              data-desktop-connect-dialog-close
            >
              <Icons.icon_close_pixel class="w-[8px] h-[7px]" />
            </.tool_button>
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
            <.button id={"#{@id}-ok"} data-desktop-connect-dialog-close>
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp launcher_groups(assigns) do
    cap = capabilities(assigns)

    ([
       group(:site, dgettext("landing", "About this site"), :icon_hex_stone, site_items(cap)),
       group(:view, dgettext("ui", "View"), :icon_channels, view_items(cap)),
       group(:tools, dgettext("ui", "Tools"), :icon_group_tools, tools_items(cap)),
       group(:accessories, dgettext("ui", "Accessories"), :icon_paint, accessories_items(cap)),
       group(
         :automation,
         dgettext("ui", "Automation"),
         :icon_dialog_perform,
         automation_items(cap)
       )
     ] ++
       catalogues() ++
       [
         group(:account, dgettext("ui", "Account"), :icon_status_user, account_items(cap)),
         group(:admin, dgettext("ui", "Admin"), :icon_shield, admin_items(cap)),
         group(:system, dgettext("ui", "System"), :icon_server, system_items(cap)),
         group(:language, dgettext("ui", "Language"), :icon_globe, language_items(cap)),
         group(:help, dgettext("ui", "Help"), :icon_group_help, help_items(cap))
       ])
    |> Enum.reject(&privileged_group_hidden?(&1, cap))
    |> Enum.with_index()
    |> Enum.map(fn {group, index} ->
      group
      |> Map.put(:window_id, "desktop-launcher-#{group.id}")
      |> Map.put(:default_x, 72 + rem(index, 4) * 28)
      |> Map.put(:default_y, 48 + div(index, 4) * 28)
    end)
  end

  defp site_shortcuts do
    about = About.window()

    Enum.map(PublicPages.all(), &{:page, &1}) ++
      [{:window, %{id: Document.window_id(about), label: about.title, icon_fn: about.icon}}]
  end

  # README.txt and the Trash, at the foot of the app's column, where Windows
  # kept its own.
  defp desktop_files, do: Enum.map(DesktopFiles.files(), &{:file, &1})

  defp launcher_window_groups(%{screen: :chat} = assigns), do: launcher_groups(assigns)

  defp launcher_window_groups(assigns) do
    assigns
    |> launcher_groups()
    |> Enum.filter(&(&1.id in [:language, :help]))
  end

  # Every folder's window: the desktop's own folders, then every folder inside
  # them, at any depth, each cascading a step from the last.
  defp folder_windows(assigns) do
    groups = launcher_window_groups(assigns)

    nested =
      groups
      |> Enum.flat_map(&subfolders/1)
      |> Enum.with_index()
      |> Enum.map(fn {folder, index} ->
        folder
        |> Map.put(:default_x, 120 + rem(index, 6) * 24)
        |> Map.put(:default_y, 56 + rem(index, 6) * 24)
      end)

    groups ++ nested
  end

  defp subfolders(folder) do
    for %{kind: :folder, folder: child} <- folder.items,
        node <- [child | subfolders(child)],
        do: node
  end

  @doc """
  What follows the window id's common prefix — `games`, `arcade-fps` — which
  names a folder's window, grid, taskbar button and menu rows in tests, and is
  unique wherever the folder sits.
  """
  @spec folder_key(%{required(:window_id) => String.t(), optional(atom()) => any()}) ::
          String.t()
  def folder_key(folder), do: String.replace_prefix(folder.window_id, "desktop-launcher-", "")

  defp desktop_icon_available?(:chat, _group), do: true
  defp desktop_icon_available?(_screen, %{id: :site}), do: false
  defp desktop_icon_available?(_screen, %{id: id}) when id in [:language, :help], do: true
  defp desktop_icon_available?(_screen, _group), do: false

  defp capabilities(assigns) do
    screen = assigns.screen
    chat? = screen == :chat

    %{
      screen: screen,
      chat?: chat?,
      help?: assigns[:help_open] == true,
      admin?: chat? and assigns.is_admin,
      current_path: assigns.current_path,
      language_return_to: assigns.language_return_to,
      on_action: assigns.on_action
    }
  end

  defp group(id, label, icon_fn, items),
    do: %{id: id, label: label, icon_fn: icon_fn, items: items, view: :icons}

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
        target: "#help-viewer",
        testid: "desktop-launcher-item-help-contents"
      ),
      action(cap, "help_nav_tab", dgettext("help", "Index"), :icon_btn_channel_list,
        disabled: !cap.help?,
        on_action: "help_nav_tab",
        value_tab: "index",
        target: "#help-viewer",
        testid: "desktop-launcher-item-help-index"
      ),
      action(cap, "help_nav_tab", dgettext("help", "Search"), :icon_btn_search,
        disabled: !cap.help?,
        on_action: "help_nav_tab",
        value_tab: "search",
        target: "#help-viewer",
        testid: "desktop-launcher-item-help-search"
      )
    ]
  end

  defp tools_items(cap), do: group_items(cap, :tools)

  defp accessories_items(cap), do: group_items(cap, :accessories)

  defp automation_items(cap), do: group_items(cap, :automation)

  defp account_items(cap), do: group_items(cap, :account)

  defp group_items(cap, group) do
    for item <- AppGroups.items(group) do
      case item do
        %{kind: :window} ->
          window(item.window, item.label, item.icon_fn, disabled: !cap.chat?)

        %{kind: :action} ->
          action(cap, item.action, item.label, item.icon_fn, disabled: !cap.chat?)

        %{kind: :separator} ->
          separator()

        %{kind: :folder} ->
          item
      end
    end
  end

  defp admin_items(cap) do
    for {action, label, icon_fn} <- WindowRegistry.menu_entries(:admin) do
      action(cap, action, label, icon_fn, disabled: !cap.admin?)
    end
  end

  defp system_items(cap) do
    for {action, label, icon_fn} <- WindowRegistry.menu_entries(:system) do
      action(cap, action, label, icon_fn, disabled: !cap.admin?)
    end
  end

  defp language_items(cap) do
    Enum.map(LanguageMenu.shell_locale_links(cap), fn locale ->
      link(locale.href, locale.label, :icon_globe,
        icon_kind: :flag,
        locale: locale.code,
        hreflang: locale.bcp47,
        testid: "desktop-launcher-item-language-#{locale.code}"
      )
    end)
  end

  # Every page of the site, and its guides and help, opened as windows over the
  # chat: a patch, never a page load, because they are all addresses of the one
  # desktop.
  defp site_items(_cap) do
    pages =
      for page <- PublicPages.all() ++ PublicPages.guides() do
        patch(PublicPages.localized_path(page.path), page.label, page.icon,
          testid: "desktop-launcher-item-site-#{page.page}"
        )
      end

    pages ++
      [
        separator(),
        patch(
          PublicPages.localized_path("/chat/help"),
          dgettext("landing", "Documentation"),
          :icon_notepad,
          testid: "desktop-launcher-item-site-help"
        ),
        about_item()
      ]
  end

  defp about_item do
    about = About.window()
    window(Document.window_id(about), about.title, about.icon, [])
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
      link("https://github.com/rodrigomarchi/retrohexchat", "GitHub", :icon_code,
        target: "_blank",
        rel: "noopener",
        testid: "desktop-launcher-item-github"
      ),
      link(
        "https://github.com/rodrigomarchi/retrohexchat/blob/main/LICENSE",
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

  defp help_topics_item(%{screen: :chat} = cap) do
    action(cap, "help_topics", dgettext("ui", "Help Topics"), :icon_btn_help_topics,
      on_action: "help_topics",
      testid: "desktop-launcher-item-help_topics"
    )
  end

  defp help_topics_item(_cap) do
    link(
      PublicPages.localized_path("/chat/help"),
      dgettext("ui", "Help Topics"),
      :icon_btn_help_topics,
      testid: "desktop-launcher-item-help_topics"
    )
  end

  defp about_item(_cap) do
    window(
      Document.window_id(About.window()),
      dgettext("ui", "About RetroHexChat"),
      :icon_dialog_about,
      testid: "desktop-launcher-item-show_about"
    )
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
      value_tab: Keyword.get(opts, :value_tab),
      target: Keyword.get(opts, :target)
    }
  end

  @doc """
  A folder inside a folder: an item that opens a window of its own (`window_id`)
  showing `items` — as icons, or as screenshot cards with `view: :cards`, whose
  items are `card/3`s. The Start menu shows it as a submenu.
  """
  @spec folder(String.t(), atom(), String.t(), atom(), [map()], keyword()) :: map()
  def folder(window_id, id, label, icon_fn, items, opts \\ []) do
    node = %{
      id: id,
      label: label,
      icon_fn: icon_fn,
      window_id: window_id,
      view: Keyword.get(opts, :view, :icons),
      items: items
    }

    %{
      kind: :folder,
      folder: node,
      window: window_id,
      label: label,
      icon_fn: icon_fn,
      disabled: false,
      testid: Keyword.get(opts, :testid, "desktop-launcher-item-folder-#{folder_key(node)}")
    }
  end

  @doc """
  A game in a `view: :cards` folder: its screenshot card, opening `path` as
  a patch. Anywhere a folder shows icons — the Start menu — it is the game's
  icon and name.
  """
  @spec card(GameCatalog.game(), String.t(), String.t()) :: map()
  def card(game, path, testid) do
    %{
      kind: :card,
      game: game,
      path: path,
      label: game.name,
      icon_fn: Registry.game(game.id),
      icon_kind: :icon,
      disabled: false,
      testid: testid
    }
  end

  defp patch(path, label, icon_fn, opts) do
    %{
      kind: :patch,
      path: path,
      label: label,
      icon_fn: icon_fn,
      icon_kind: :icon,
      disabled: false,
      testid: Keyword.fetch!(opts, :testid)
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
      confirm_tab: Keyword.get(opts, :confirm_tab),
      confirm_label: Keyword.get(opts, :confirm_label),
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

  defp separator, do: %{kind: :separator}

  attr :item, :map, required: true

  defp launcher_item(%{item: %{kind: :separator}} = assigns) do
    ~H"""
    <div class="desktop-launcher-separator" role="presentation"></div>
    """
  end

  defp launcher_item(%{item: %{kind: kind}} = assigns) when kind in [:window, :folder] do
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
      phx-target={@item.target}
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
      data-confirm-tab={@item.confirm_tab}
      data-confirm-label={@item.confirm_label}
      data-testid={@item.testid}
    >
      <.launcher_item_icon item={@item} class="h-8 w-8" />
      <span class="desktop-launcher-item__label">{@item.label}</span>
    </.link>
    """
  end

  defp launcher_item(%{item: %{kind: kind}} = assigns) when kind in [:patch, :card] do
    assigns = assign_item_class(assigns)

    ~H"""
    <.link patch={@item.path} class={@item_class} data-testid={@item.testid}>
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

  defp assign_item_class(assigns) do
    item = assigns.item

    assign(assigns, :item_class, [
      "desktop-launcher-item",
      item.kind == :link && "text-text no-underline",
      item[:class]
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
