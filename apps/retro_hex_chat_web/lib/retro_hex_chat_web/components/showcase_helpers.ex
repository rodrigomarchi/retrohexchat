defmodule RetroHexChatWeb.ShowcaseHelpers do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.TreeView
  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.MenuBarApp
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.Components.UI.AboutDialog

  alias RetroHexChatWeb.Icons

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  @doc "Full-page showcase wrapper with sidebar navigation and content area."
  attr :active_page, :string, required: true
  slot :inner_block, required: true

  # Nav tree: {group_label, group_icon_fn, [{label, id, path}]}
  @nav_items [
    {dgettext_noop("showcase", "Primitives"), :icon_btn_ok,
     [
       {dgettext_noop("showcase", "Accordion"), "accordion", "/showcase/accordion"},
       {dgettext_noop("showcase", "Alert"), "alert", "/showcase/alert"},
       {dgettext_noop("showcase", "Alert Dialog"), "alert-dialog", "/showcase/alert-dialog"},
       {dgettext_noop("showcase", "Avatar"), "avatar", "/showcase/avatar"},
       {dgettext_noop("showcase", "Badge"), "badge", "/showcase/badge"},
       {dgettext_noop("showcase", "Breadcrumb"), "breadcrumb", "/showcase/breadcrumb"},
       {dgettext_noop("showcase", "Button"), "button", "/showcase/button"},
       {dgettext_noop("showcase", "Card"), "card", "/showcase/card"},
       {dgettext_noop("showcase", "Checkbox"), "checkbox", "/showcase/checkbox"},
       {dgettext_noop("showcase", "Dropdown Menu"), "dropdown-menu", "/showcase/dropdown-menu"},
       {dgettext_noop("showcase", "Form"), "form", "/showcase/form"},
       {dgettext_noop("showcase", "Input"), "input", "/showcase/input"},
       {dgettext_noop("showcase", "Label"), "label", "/showcase/label"},
       {dgettext_noop("showcase", "Pagination"), "pagination", "/showcase/pagination"},
       {dgettext_noop("showcase", "Popover"), "popover", "/showcase/popover"},
       {dgettext_noop("showcase", "Progress"), "progress", "/showcase/progress"},
       {dgettext_noop("showcase", "Radio Group"), "radio-group", "/showcase/radio-group"},
       {dgettext_noop("showcase", "Select"), "select", "/showcase/select"},
       {dgettext_noop("showcase", "Separator"), "separator", "/showcase/separator"},
       {dgettext_noop("showcase", "Sheet"), "sheet", "/showcase/sheet"},
       {dgettext_noop("showcase", "Skeleton"), "skeleton", "/showcase/skeleton"},
       {dgettext_noop("showcase", "Slider"), "slider", "/showcase/slider"},
       {dgettext_noop("showcase", "Switch"), "switch", "/showcase/switch"},
       {dgettext_noop("showcase", "Textarea"), "textarea", "/showcase/textarea"},
       {dgettext_noop("showcase", "Toggle"), "toggle", "/showcase/toggle"},
       {dgettext_noop("showcase", "Toggle Group"), "toggle-group", "/showcase/toggle-group"},
       {dgettext_noop("showcase", "Tooltip"), "tooltip", "/showcase/tooltip"}
     ]},
    {dgettext_noop("showcase", "Layout"), :icon_group_view,
     [
       {dgettext_noop("showcase", "Context Menu"), "context-menu", "/showcase/context-menu"},
       {dgettext_noop("showcase", "Dialog"), "dialog", "/showcase/dialog"},
       {dgettext_noop("showcase", "Fieldset"), "fieldset", "/showcase/fieldset"},
       {dgettext_noop("showcase", "Menu"), "menu", "/showcase/menu"},
       {dgettext_noop("showcase", "Scroll Area"), "scroll-area", "/showcase/scroll-area"},
       {dgettext_noop("showcase", "Table"), "table", "/showcase/table"},
       {dgettext_noop("showcase", "Tabs"), "tabs", "/showcase/tabs"},
       {dgettext_noop("showcase", "Toast"), "toast", "/showcase/toast"},
       {dgettext_noop("showcase", "Toolbar"), "toolbar", "/showcase/toolbar"},
       {dgettext_noop("showcase", "Tree View"), "tree-view", "/showcase/tree-view"},
       {dgettext_noop("showcase", "Window"), "window", "/showcase/window"}
     ]},
    {dgettext_noop("showcase", "Chat"), :icon_chat,
     [
       {dgettext_noop("showcase", "Autocomplete"), "autocomplete", "/showcase/autocomplete"},
       {dgettext_noop("showcase", "Chat Context Menu"), "chat-context-menu",
        "/showcase/chat-context-menu"},
       {dgettext_noop("showcase", "Chat Input"), "chat-input", "/showcase/chat-input"},
       {dgettext_noop("showcase", "Chat Layout"), "chat-layout", "/showcase/chat-layout"},
       {dgettext_noop("showcase", "Chat Message"), "chat-message", "/showcase/chat-message"},
       {dgettext_noop("showcase", "Color Picker"), "color-picker", "/showcase/color-picker"},
       {dgettext_noop("showcase", "Connection Status"), "connection-status",
        "/showcase/connection-status"},
       {dgettext_noop("showcase", "Conversations"), "conversations", "/showcase/conversations"},
       {dgettext_noop("showcase", "Conversations Ctx Menu"), "conversations-context-menu",
        "/showcase/conversations-context-menu"},
       {dgettext_noop("showcase", "Emoji Picker"), "emoji-picker", "/showcase/emoji-picker"},
       {dgettext_noop("showcase", "Formatting Toolbar"), "formatting-toolbar",
        "/showcase/formatting-toolbar"},
       {dgettext_noop("showcase", "History Search"), "history-search",
        "/showcase/history-search"},
       {dgettext_noop("showcase", "Hover Card"), "hover-card", "/showcase/hover-card"},
       {dgettext_noop("showcase", "IRC Tabs"), "irc-tabs", "/showcase/irc-tabs"},
       {dgettext_noop("showcase", "Nicklist"), "nicklist", "/showcase/nicklist"},
       {dgettext_noop("showcase", "Reply Bar"), "reply-bar", "/showcase/reply-bar"},
       {dgettext_noop("showcase", "Scroll Loader"), "scroll-loader", "/showcase/scroll-loader"},
       {dgettext_noop("showcase", "Search Bar"), "search-bar", "/showcase/search-bar"},
       {dgettext_noop("showcase", "Syntax Tooltip"), "syntax-tooltip",
        "/showcase/syntax-tooltip"},
       {dgettext_noop("showcase", "Tab Bar"), "tab-bar", "/showcase/tab-bar"},
       {dgettext_noop("showcase", "Topic Bar"), "topic-bar", "/showcase/topic-bar"}
     ]},
    {dgettext_noop("showcase", "Shell"), :icon_laptop,
     [
       {dgettext_noop("showcase", "App Header"), "app-header", "/showcase/app-header"},
       {dgettext_noop("showcase", "Config Form"), "config-form", "/showcase/config-form"},
       {dgettext_noop("showcase", "Empty State"), "empty-state", "/showcase/empty-state"},
       {dgettext_noop("showcase", "Loading Spinner"), "loading-spinner",
        "/showcase/loading-spinner"},
       {dgettext_noop("showcase", "Status Bar"), "status-bar", "/showcase/status-bar"},
       {dgettext_noop("showcase", "Status Bar App"), "status-bar-app",
        "/showcase/status-bar-app"},
       {dgettext_noop("showcase", "Toolbar App"), "toolbar-app", "/showcase/toolbar-app"}
     ]},
    {dgettext_noop("showcase", "Dialogs"), :icon_dialog_options,
     [
       {dgettext_noop("showcase", "About Dialog"), "about-dialog", "/showcase/about-dialog"},
       {dgettext_noop("showcase", "Address Book"), "address-book", "/showcase/address-book"},
       {dgettext_noop("showcase", "Admin Console"), "admin-console-dialog",
        "/showcase/admin-console-dialog"},
       {dgettext_noop("showcase", "Alias Dialog"), "alias-dialog", "/showcase/alias-dialog"},
       {dgettext_noop("showcase", "Auto Respond"), "auto-respond-dialog",
        "/showcase/auto-respond-dialog"},
       {dgettext_noop("showcase", "Bot Management"), "bot-management-dialog",
        "/showcase/bot-management-dialog"},
       {dgettext_noop("showcase", "Channel Central"), "channel-central-dialog",
        "/showcase/channel-central-dialog"},
       {dgettext_noop("showcase", "Channel Dialog"), "channel-dialog",
        "/showcase/channel-dialog"},
       {dgettext_noop("showcase", "Channel List"), "channel-list", "/showcase/channel-list"},
       {dgettext_noop("showcase", "Cheatsheet"), "cheatsheet-dialog",
        "/showcase/cheatsheet-dialog"},
       {dgettext_noop("showcase", "Confirm Dialog"), "confirm-dialog",
        "/showcase/confirm-dialog"},
       {dgettext_noop("showcase", "Custom Menus"), "custom-menus-dialog",
        "/showcase/custom-menus-dialog"},
       {dgettext_noop("showcase", "Delete Confirm"), "delete-confirm-dialog",
        "/showcase/delete-confirm-dialog"},
       {dgettext_noop("showcase", "Disconnect Confirm"), "disconnect-confirm-dialog",
        "/showcase/disconnect-confirm-dialog"},
       {dgettext_noop("showcase", "Flood Protection"), "flood-protection-dialog",
        "/showcase/flood-protection-dialog"},
       {dgettext_noop("showcase", "Highlight Dialog"), "highlight-dialog",
        "/showcase/highlight-dialog"},
       {dgettext_noop("showcase", "Invite Dialog"), "invite-dialog", "/showcase/invite-dialog"},
       {dgettext_noop("showcase", "Kick Dialog"), "kick-dialog", "/showcase/kick-dialog"},
       {dgettext_noop("showcase", "Nick Change"), "nick-change-dialog",
        "/showcase/nick-change-dialog"},
       {dgettext_noop("showcase", "Notify List"), "notify-list", "/showcase/notify-list"},
       {dgettext_noop("showcase", "Paste Confirm"), "paste-confirm-dialog",
        "/showcase/paste-confirm-dialog"},
       {dgettext_noop("showcase", "Perform Dialog"), "perform-dialog",
        "/showcase/perform-dialog"},
       {dgettext_noop("showcase", "Sound Settings"), "sound-settings-dialog",
        "/showcase/sound-settings-dialog"},
       {dgettext_noop("showcase", "URL Catcher"), "url-catcher", "/showcase/url-catcher"}
     ]},
    {dgettext_noop("showcase", "P2P"), :icon_p2p,
     [
       {dgettext_noop("showcase", "Connection Diagram"), "p2p-connection-diagram",
        "/showcase/p2p-connection-diagram"},
       {dgettext_noop("showcase", "File Transfer"), "file-transfer", "/showcase/file-transfer"},
       {dgettext_noop("showcase", "Media Controls"), "media-controls",
        "/showcase/media-controls"},
       {dgettext_noop("showcase", "P2P Lobby"), "p2p-lobby", "/showcase/p2p-lobby"}
     ]},
    {dgettext_noop("showcase", "Games"), :icon_joystick,
     [
       {dgettext_noop("showcase", "Arcade Frame"), "arcade-frame", "/showcase/arcade-frame"},
       {dgettext_noop("showcase", "Game Canvas"), "game-canvas", "/showcase/game-canvas"},
       {dgettext_noop("showcase", "Game Cards"), "game-cards", "/showcase/game-cards"},
       {dgettext_noop("showcase", "Game Lobby"), "game-lobby", "/showcase/game-lobby"},
       {dgettext_noop("showcase", "Solo Lobby"), "solo-lobby", "/showcase/solo-lobby"}
     ]},
    {dgettext_noop("showcase", "Assets"), :icon_folder,
     [
       {dgettext_noop("showcase", "Diagrams"), "diagrams", "/showcase/diagrams"},
       {dgettext_noop("showcase", "Icons"), "icons", "/showcase/icons"}
     ]}
  ]

  @spec showcase_layout(map()) :: Phoenix.LiveView.Rendered.t()
  def showcase_layout(assigns) do
    nav_items =
      Enum.map(@nav_items, fn {label, icon_fn, items} ->
        group_active = Enum.any?(items, fn {_, id, _} -> id == assigns.active_page end)

        translated_items =
          Enum.map(items, fn {item_label, id, path} ->
            {t(item_label), id, path}
          end)

        {t(label), icon_fn, translated_items, group_active}
      end)

    assigns = assign(assigns, :nav_items, nav_items)

    ~H"""
    <div class="min-h-screen bg-desktop font-system text-text flex flex-col">
      <.app_header on_logo_click={show_modal("about-dialog")}>
        <:panels>
          <.menu_bar_app id="menubar" phx-hook="MenuBarHook" connected={false} />
        </:panels>
      </.app_header>

      <div class="flex-1 m-2 md:m-4 md:mt-2">
        <div class="shadow-retro-window bg-surface p-1">
          <div class="bg-gradient-to-r from-primary to-highlight-light text-white px-2 py-1 font-bold text-xs flex items-center justify-between">
            <span>{dgettext("showcase", "Component Showcase")}</span>
            <button
              type="button"
              class="md:hidden text-white text-xs px-1"
              onclick="document.getElementById('showcase-nav').classList.toggle('hidden')"
            >
              {dgettext("showcase", "Menu")}
            </button>
          </div>

          <div class="flex flex-col md:flex-row p-1">
            <nav
              id="showcase-nav"
              class="hidden md:block shadow-retro-sunken bg-white w-full md:w-48 md:mr-2 md:shrink-0 overflow-y-auto p-1 max-h-[50vh] md:max-h-[calc(100vh-120px)]"
            >
              <.tree_view class="!shadow-none !p-0 !bg-transparent">
                <.link navigate="/showcase" class="block no-underline">
                  <.tree_view_item active={@active_page == "index"}>
                    <:icon><Icons.icon_palette class="w-3 h-3" /></:icon>
                    {dgettext("showcase", "Design System")}
                  </.tree_view_item>
                </.link>
                <.tree_view_group
                  :for={{group_label, group_icon_fn, items, group_active} <- @nav_items}
                  label={group_label}
                  open={group_active}
                >
                  <:icon>{apply(Icons, group_icon_fn, [%{class: "w-4 h-4"}])}</:icon>
                  <.link
                    :for={{label, id, path} <- items}
                    navigate={path}
                    class="block no-underline"
                  >
                    <.tree_view_item active={@active_page == id}>
                      <:icon><.nav_item_icon id={id} /></:icon>
                      {label}
                    </.tree_view_item>
                  </.link>
                </.tree_view_group>
              </.tree_view>
            </nav>

            <div class="shadow-retro-sunken bg-gray-100 flex-1 p-2 md:p-3 overflow-y-auto max-h-[calc(100vh-120px)]">
              {render_slot(@inner_block)}
            </div>
          </div>
        </div>
      </div>
      <.about_dialog id="about-dialog" />
    </div>
    """
  end

  @doc "Retro-styled showcase card with title bar, description, and rendered content."
  attr :title, :string, required: true
  attr :description, :string, required: true
  slot :inner_block, required: true

  def showcase_card(assigns) do
    ~H"""
    <div class="shadow-retro-window bg-surface p-1 mb-4">
      <div class="bg-gradient-to-r from-primary to-highlight-light text-white px-2 py-1 font-bold text-xs">
        {@title}
      </div>
      <div class="p-2">
        <p class="text-xs text-muted-foreground mb-2">{@description}</p>
        <div class="shadow-retro-sunken bg-white p-3">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  @doc "Dark terminal-style code block with syntax highlighting."
  attr :language, :string, default: "elixir"
  slot :inner_block, required: true

  def code_example(assigns) do
    assigns = assign(assigns, :uid, System.unique_integer([:positive]))

    ~H"""
    <div
      id={"code-#{@uid}"}
      phx-hook="Highlight"
      class="shadow-retro-field bg-canvas-bg text-canvas-fg p-3 mt-2 overflow-x-auto"
    >
      <pre class="text-xs font-mono whitespace-pre"><code class={"language-#{@language}"}>{render_slot(@inner_block)}</code></pre>
    </div>
    """
  end

  # ── Nav item icons ───────────────────────────────────────

  attr :id, :string, required: true

  @nav_icon_map %{
    "index" => :icon_palette,
    "button" => :icon_btn_ok,
    "input" => :icon_btn_edit,
    "label" => :icon_tag,
    "textarea" => :icon_notepad,
    "select" => :icon_btn_down,
    "checkbox" => :icon_checkmark,
    "radio-group" => :icon_btn_ok,
    "switch" => :icon_tab_control,
    "slider" => :icon_tab_control,
    "toggle" => :icon_tab_control,
    "toggle-group" => :icon_tab_control,
    "alert" => :icon_warning,
    "badge" => :icon_tag,
    "progress" => :icon_status_signal,
    "skeleton" => :icon_clock,
    "tooltip" => :icon_lightbulb,
    "card" => :icon_group_view,
    "separator" => :icon_tab_control,
    "sheet" => :icon_group_view,
    "tabs" => :icon_tab_general,
    "accordion" => :icon_btn_down,
    "avatar" => :icon_status_user,
    "dialog" => :icon_dialog_options,
    "dropdown-menu" => :icon_btn_down,
    "bot-management-dialog" => :icon_dialog_bot_management,
    "breadcrumb" => :icon_btn_next,
    "pagination" => :icon_btn_prev,
    "popover" => :icon_lightbulb,
    "fieldset" => :icon_group_view,
    "form" => :icon_btn_edit,
    "table" => :icon_database,
    "window" => :icon_laptop,
    "menu" => :icon_dialog_custom_menus,
    "toolbar" => :icon_group_tools,
    "status-bar" => :icon_status_signal,
    "irc-tabs" => :icon_tab_channel,
    "chat-message" => :icon_chat,
    "chat-input" => :icon_send,
    "tree-view" => :icon_folder,
    "nicklist" => :icon_tab_nicklist,
    "game-cards" => :icon_joystick,
    "icons" => :icon_star,
    "diagrams" => :icon_code,
    "toast" => :icon_btn_bell,
    "context-menu" => :icon_dialog_custom_menus,
    "loading-spinner" => :icon_clock,
    "empty-state" => :icon_group_view,
    "color-picker" => :icon_tab_colors,
    "scroll-area" => :icon_btn_down,
    "conversations" => :icon_tab_conversations,
    "hover-card" => :icon_status_user,
    "search-bar" => :icon_btn_find,
    "topic-bar" => :icon_tab_channel,
    "formatting-toolbar" => :icon_fmt_bold,
    "emoji-picker" => :icon_fmt_emoji,
    "autocomplete" => :icon_btn_down,
    "tab-bar" => :icon_tab_channel,
    "reply-bar" => :icon_retry,
    "connection-status" => :icon_status_signal,
    "confirm-dialog" => :icon_warning,
    "channel-dialog" => :icon_tab_channel,
    "address-book" => :icon_dialog_address_book,
    "about-dialog" => :icon_lightbulb,
    "admin-console-dialog" => :icon_dialog_admin_console,
    "alert-dialog" => :icon_warning,
    "channel-list" => :icon_channels,
    "highlight-dialog" => :icon_star,
    "config-form" => :icon_btn_settings,
    "p2p-lobby" => :icon_p2p,
    "media-controls" => :icon_microphone,
    "file-transfer" => :icon_file_send,
    "chat-layout" => :icon_chat,
    "scroll-loader" => :icon_clock,
    "history-search" => :icon_btn_find,
    "kick-dialog" => :icon_dialog_kick,
    "delete-confirm-dialog" => :icon_dialog_delete,
    "disconnect-confirm-dialog" => :icon_btn_disconnect,
    "status-bar-app" => :icon_status_signal,
    "conversations-context-menu" => :icon_tab_conversations,
    "game-canvas" => :icon_joystick,
    "alias-dialog" => :icon_dialog_alias,
    "flood-protection-dialog" => :icon_dialog_flood,
    "notify-list" => :icon_btn_bell,
    "url-catcher" => :icon_link,
    "game-lobby" => :icon_joystick,
    "auto-respond-dialog" => :icon_dialog_auto_respond,
    "custom-menus-dialog" => :icon_dialog_custom_menus,
    "sound-settings-dialog" => :icon_dialog_sound,
    "invite-dialog" => :icon_btn_join,
    "paste-confirm-dialog" => :icon_warning,
    "arcade-frame" => :icon_joystick,
    "app-header" => :icon_laptop,
    "cheatsheet-dialog" => :icon_btn_keyboard,
    "nick-change-dialog" => :icon_status_user,
    "syntax-tooltip" => :icon_lightbulb,
    "toolbar-app" => :icon_group_tools,
    "solo-lobby" => :icon_joystick,
    "chat-context-menu" => :icon_dialog_custom_menus,
    "perform-dialog" => :icon_dialog_perform,
    "channel-central-dialog" => :icon_dialog_channel_central
  }

  defp nav_item_icon(assigns) do
    icon_fn = Map.get(@nav_icon_map, assigns.id)
    assigns = assign(assigns, :icon_fn, icon_fn)

    ~H"""
    {if @icon_fn, do: apply(Icons, @icon_fn, [%{class: "w-3 h-3"}])}
    """
  end

  defp t(msgid), do: Gettext.dgettext(RetroHexChatWeb.Gettext, "showcase", msgid)
end
