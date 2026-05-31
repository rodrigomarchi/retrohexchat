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
    {gettext_noop("Primitives"), :icon_btn_ok,
     [
       {gettext_noop("Accordion"), "accordion", "/showcase/accordion"},
       {gettext_noop("Alert"), "alert", "/showcase/alert"},
       {gettext_noop("Alert Dialog"), "alert-dialog", "/showcase/alert-dialog"},
       {gettext_noop("Avatar"), "avatar", "/showcase/avatar"},
       {gettext_noop("Badge"), "badge", "/showcase/badge"},
       {gettext_noop("Breadcrumb"), "breadcrumb", "/showcase/breadcrumb"},
       {gettext_noop("Button"), "button", "/showcase/button"},
       {gettext_noop("Card"), "card", "/showcase/card"},
       {gettext_noop("Checkbox"), "checkbox", "/showcase/checkbox"},
       {gettext_noop("Dropdown Menu"), "dropdown-menu", "/showcase/dropdown-menu"},
       {gettext_noop("Form"), "form", "/showcase/form"},
       {gettext_noop("Input"), "input", "/showcase/input"},
       {gettext_noop("Label"), "label", "/showcase/label"},
       {gettext_noop("Pagination"), "pagination", "/showcase/pagination"},
       {gettext_noop("Popover"), "popover", "/showcase/popover"},
       {gettext_noop("Progress"), "progress", "/showcase/progress"},
       {gettext_noop("Radio Group"), "radio-group", "/showcase/radio-group"},
       {gettext_noop("Select"), "select", "/showcase/select"},
       {gettext_noop("Separator"), "separator", "/showcase/separator"},
       {gettext_noop("Sheet"), "sheet", "/showcase/sheet"},
       {gettext_noop("Skeleton"), "skeleton", "/showcase/skeleton"},
       {gettext_noop("Slider"), "slider", "/showcase/slider"},
       {gettext_noop("Switch"), "switch", "/showcase/switch"},
       {gettext_noop("Textarea"), "textarea", "/showcase/textarea"},
       {gettext_noop("Toggle"), "toggle", "/showcase/toggle"},
       {gettext_noop("Toggle Group"), "toggle-group", "/showcase/toggle-group"},
       {gettext_noop("Tooltip"), "tooltip", "/showcase/tooltip"}
     ]},
    {gettext_noop("Layout"), :icon_group_view,
     [
       {gettext_noop("Context Menu"), "context-menu", "/showcase/context-menu"},
       {gettext_noop("Dialog"), "dialog", "/showcase/dialog"},
       {gettext_noop("Fieldset"), "fieldset", "/showcase/fieldset"},
       {gettext_noop("Menu"), "menu", "/showcase/menu"},
       {gettext_noop("Scroll Area"), "scroll-area", "/showcase/scroll-area"},
       {gettext_noop("Table"), "table", "/showcase/table"},
       {gettext_noop("Tabs"), "tabs", "/showcase/tabs"},
       {gettext_noop("Toast"), "toast", "/showcase/toast"},
       {gettext_noop("Toolbar"), "toolbar", "/showcase/toolbar"},
       {gettext_noop("Tree View"), "tree-view", "/showcase/tree-view"},
       {gettext_noop("Window"), "window", "/showcase/window"}
     ]},
    {gettext_noop("Chat"), :icon_chat,
     [
       {gettext_noop("Autocomplete"), "autocomplete", "/showcase/autocomplete"},
       {gettext_noop("Chat Context Menu"), "chat-context-menu", "/showcase/chat-context-menu"},
       {gettext_noop("Chat Input"), "chat-input", "/showcase/chat-input"},
       {gettext_noop("Chat Layout"), "chat-layout", "/showcase/chat-layout"},
       {gettext_noop("Chat Message"), "chat-message", "/showcase/chat-message"},
       {gettext_noop("Color Picker"), "color-picker", "/showcase/color-picker"},
       {gettext_noop("Connection Status"), "connection-status", "/showcase/connection-status"},
       {gettext_noop("Conversations"), "conversations", "/showcase/conversations"},
       {gettext_noop("Conversations Ctx Menu"), "conversations-context-menu",
        "/showcase/conversations-context-menu"},
       {gettext_noop("Emoji Picker"), "emoji-picker", "/showcase/emoji-picker"},
       {gettext_noop("Formatting Toolbar"), "formatting-toolbar", "/showcase/formatting-toolbar"},
       {gettext_noop("History Search"), "history-search", "/showcase/history-search"},
       {gettext_noop("Hover Card"), "hover-card", "/showcase/hover-card"},
       {gettext_noop("IRC Tabs"), "irc-tabs", "/showcase/irc-tabs"},
       {gettext_noop("Nicklist"), "nicklist", "/showcase/nicklist"},
       {gettext_noop("Reply Bar"), "reply-bar", "/showcase/reply-bar"},
       {gettext_noop("Scroll Loader"), "scroll-loader", "/showcase/scroll-loader"},
       {gettext_noop("Search Bar"), "search-bar", "/showcase/search-bar"},
       {gettext_noop("Syntax Tooltip"), "syntax-tooltip", "/showcase/syntax-tooltip"},
       {gettext_noop("Tab Bar"), "tab-bar", "/showcase/tab-bar"},
       {gettext_noop("Topic Bar"), "topic-bar", "/showcase/topic-bar"}
     ]},
    {gettext_noop("Shell"), :icon_laptop,
     [
       {gettext_noop("App Header"), "app-header", "/showcase/app-header"},
       {gettext_noop("Config Form"), "config-form", "/showcase/config-form"},
       {gettext_noop("Empty State"), "empty-state", "/showcase/empty-state"},
       {gettext_noop("Loading Spinner"), "loading-spinner", "/showcase/loading-spinner"},
       {gettext_noop("Status Bar"), "status-bar", "/showcase/status-bar"},
       {gettext_noop("Status Bar App"), "status-bar-app", "/showcase/status-bar-app"},
       {gettext_noop("Toolbar App"), "toolbar-app", "/showcase/toolbar-app"}
     ]},
    {gettext_noop("Dialogs"), :icon_dialog_options,
     [
       {gettext_noop("About Dialog"), "about-dialog", "/showcase/about-dialog"},
       {gettext_noop("Address Book"), "address-book", "/showcase/address-book"},
       {gettext_noop("Admin Console"), "admin-console-dialog", "/showcase/admin-console-dialog"},
       {gettext_noop("Alias Dialog"), "alias-dialog", "/showcase/alias-dialog"},
       {gettext_noop("Auto Respond"), "auto-respond-dialog", "/showcase/auto-respond-dialog"},
       {gettext_noop("Bot Management"), "bot-management-dialog",
        "/showcase/bot-management-dialog"},
       {gettext_noop("Channel Central"), "channel-central-dialog",
        "/showcase/channel-central-dialog"},
       {gettext_noop("Channel Dialog"), "channel-dialog", "/showcase/channel-dialog"},
       {gettext_noop("Channel List"), "channel-list", "/showcase/channel-list"},
       {gettext_noop("Cheatsheet"), "cheatsheet-dialog", "/showcase/cheatsheet-dialog"},
       {gettext_noop("Confirm Dialog"), "confirm-dialog", "/showcase/confirm-dialog"},
       {gettext_noop("Custom Menus"), "custom-menus-dialog", "/showcase/custom-menus-dialog"},
       {gettext_noop("Delete Confirm"), "delete-confirm-dialog",
        "/showcase/delete-confirm-dialog"},
       {gettext_noop("Disconnect Confirm"), "disconnect-confirm-dialog",
        "/showcase/disconnect-confirm-dialog"},
       {gettext_noop("Flood Protection"), "flood-protection-dialog",
        "/showcase/flood-protection-dialog"},
       {gettext_noop("Highlight Dialog"), "highlight-dialog", "/showcase/highlight-dialog"},
       {gettext_noop("Invite Dialog"), "invite-dialog", "/showcase/invite-dialog"},
       {gettext_noop("Kick Dialog"), "kick-dialog", "/showcase/kick-dialog"},
       {gettext_noop("Nick Change"), "nick-change-dialog", "/showcase/nick-change-dialog"},
       {gettext_noop("Notify List"), "notify-list", "/showcase/notify-list"},
       {gettext_noop("Paste Confirm"), "paste-confirm-dialog", "/showcase/paste-confirm-dialog"},
       {gettext_noop("Perform Dialog"), "perform-dialog", "/showcase/perform-dialog"},
       {gettext_noop("Sound Settings"), "sound-settings-dialog",
        "/showcase/sound-settings-dialog"},
       {gettext_noop("URL Catcher"), "url-catcher", "/showcase/url-catcher"}
     ]},
    {gettext_noop("P2P"), :icon_p2p,
     [
       {gettext_noop("File Transfer"), "file-transfer", "/showcase/file-transfer"},
       {gettext_noop("Media Controls"), "media-controls", "/showcase/media-controls"},
       {gettext_noop("P2P Lobby"), "p2p-lobby", "/showcase/p2p-lobby"}
     ]},
    {gettext_noop("Games"), :icon_joystick,
     [
       {gettext_noop("Arcade Frame"), "arcade-frame", "/showcase/arcade-frame"},
       {gettext_noop("Game Canvas"), "game-canvas", "/showcase/game-canvas"},
       {gettext_noop("Game Cards"), "game-cards", "/showcase/game-cards"},
       {gettext_noop("Game Lobby"), "game-lobby", "/showcase/game-lobby"},
       {gettext_noop("Solo Lobby"), "solo-lobby", "/showcase/solo-lobby"}
     ]},
    {gettext_noop("Assets"), :icon_folder,
     [
       {gettext_noop("Diagrams"), "diagrams", "/showcase/diagrams"},
       {gettext_noop("Icons"), "icons", "/showcase/icons"}
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
            <span>{gettext("Component Showcase")}</span>
            <button
              type="button"
              class="md:hidden text-white text-xs px-1"
              onclick="document.getElementById('showcase-nav').classList.toggle('hidden')"
            >
              {gettext("Menu")}
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
                    {gettext("Design System")}
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

  defp t(msgid), do: Gettext.gettext(RetroHexChatWeb.Gettext, msgid)
end
