defmodule RetroHexChatWeb.ShowcaseHelpers do
  @moduledoc false
  use Phoenix.Component

  import RetroHexChatWeb.Components.UI.TreeView
  import RetroHexChatWeb.Components.UI.AppHeader

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
    {"Primitives", :icon_btn_ok,
     [
       {"Accordion", "accordion", "/showcase/accordion"},
       {"Alert", "alert", "/showcase/alert"},
       {"Avatar", "avatar", "/showcase/avatar"},
       {"Badge", "badge", "/showcase/badge"},
       {"Breadcrumb", "breadcrumb", "/showcase/breadcrumb"},
       {"Button", "button", "/showcase/button"},
       {"Card", "card", "/showcase/card"},
       {"Checkbox", "checkbox", "/showcase/checkbox"},
       {"Dropdown Menu", "dropdown-menu", "/showcase/dropdown-menu"},
       {"Input", "input", "/showcase/input"},
       {"Label", "label", "/showcase/label"},
       {"Pagination", "pagination", "/showcase/pagination"},
       {"Progress", "progress", "/showcase/progress"},
       {"Radio Group", "radio-group", "/showcase/radio-group"},
       {"Select", "select", "/showcase/select"},
       {"Separator", "separator", "/showcase/separator"},
       {"Skeleton", "skeleton", "/showcase/skeleton"},
       {"Slider", "slider", "/showcase/slider"},
       {"Switch", "switch", "/showcase/switch"},
       {"Textarea", "textarea", "/showcase/textarea"},
       {"Toggle", "toggle", "/showcase/toggle"},
       {"Toggle Group", "toggle-group", "/showcase/toggle-group"},
       {"Tooltip", "tooltip", "/showcase/tooltip"}
     ]},
    {"Layout", :icon_group_view,
     [
       {"Context Menu", "context-menu", "/showcase/context-menu"},
       {"Dialog", "dialog", "/showcase/dialog"},
       {"Fieldset", "fieldset", "/showcase/fieldset"},
       {"Menu", "menu", "/showcase/menu"},
       {"Scroll Area", "scroll-area", "/showcase/scroll-area"},
       {"Table", "table", "/showcase/table"},
       {"Tabs", "tabs", "/showcase/tabs"},
       {"Toast", "toast", "/showcase/toast"},
       {"Toolbar", "toolbar", "/showcase/toolbar"},
       {"Tree View", "tree-view", "/showcase/tree-view"},
       {"Window", "window", "/showcase/window"}
     ]},
    {"Chat", :icon_chat,
     [
       {"Autocomplete", "autocomplete", "/showcase/autocomplete"},
       {"Chat Context Menu", "chat-context-menu", "/showcase/chat-context-menu"},
       {"Chat Input", "chat-input", "/showcase/chat-input"},
       {"Chat Layout", "chat-layout", "/showcase/chat-layout"},
       {"Chat Message", "chat-message", "/showcase/chat-message"},
       {"Color Picker", "color-picker", "/showcase/color-picker"},
       {"Connection Status", "connection-status", "/showcase/connection-status"},
       {"Conversations", "conversations", "/showcase/conversations"},
       {"Conversations Ctx Menu", "conversations-context-menu",
        "/showcase/conversations-context-menu"},
       {"Emoji Picker", "emoji-picker", "/showcase/emoji-picker"},
       {"Formatting Toolbar", "formatting-toolbar", "/showcase/formatting-toolbar"},
       {"History Search", "history-search", "/showcase/history-search"},
       {"Hover Card", "hover-card", "/showcase/hover-card"},
       {"IRC Tabs", "irc-tabs", "/showcase/irc-tabs"},
       {"Nicklist", "nicklist", "/showcase/nicklist"},
       {"Reply Bar", "reply-bar", "/showcase/reply-bar"},
       {"Scroll Loader", "scroll-loader", "/showcase/scroll-loader"},
       {"Search Bar", "search-bar", "/showcase/search-bar"},
       {"Syntax Tooltip", "syntax-tooltip", "/showcase/syntax-tooltip"},
       {"Tab Bar", "tab-bar", "/showcase/tab-bar"},
       {"Topic Bar", "topic-bar", "/showcase/topic-bar"}
     ]},
    {"Shell", :icon_laptop,
     [
       {"App Header", "app-header", "/showcase/app-header"},
       {"Config Form", "config-form", "/showcase/config-form"},
       {"Empty State", "empty-state", "/showcase/empty-state"},
       {"Loading Spinner", "loading-spinner", "/showcase/loading-spinner"},
       {"Status Bar", "status-bar", "/showcase/status-bar"},
       {"Status Bar App", "status-bar-app", "/showcase/status-bar-app"},
       {"Toolbar App", "toolbar-app", "/showcase/toolbar-app"}
     ]},
    {"Dialogs", :icon_dialog_options,
     [
       {"About Dialog", "about-dialog", "/showcase/about-dialog"},
       {"Address Book", "address-book", "/showcase/address-book"},
       {"Alias Dialog", "alias-dialog", "/showcase/alias-dialog"},
       {"Auto Respond", "auto-respond-dialog", "/showcase/auto-respond-dialog"},
       {"Channel Central", "channel-central-dialog", "/showcase/channel-central-dialog"},
       {"Channel Dialog", "channel-dialog", "/showcase/channel-dialog"},
       {"Channel List", "channel-list", "/showcase/channel-list"},
       {"Cheatsheet", "cheatsheet-dialog", "/showcase/cheatsheet-dialog"},
       {"Confirm Dialog", "confirm-dialog", "/showcase/confirm-dialog"},
       {"CTCP Settings", "ctcp-settings-dialog", "/showcase/ctcp-settings-dialog"},
       {"Custom Menus", "custom-menus-dialog", "/showcase/custom-menus-dialog"},
       {"Delete Confirm", "delete-confirm-dialog", "/showcase/delete-confirm-dialog"},
       {"Disconnect Confirm", "disconnect-confirm-dialog", "/showcase/disconnect-confirm-dialog"},
       {"Flood Protection", "flood-protection-dialog", "/showcase/flood-protection-dialog"},
       {"Highlight Dialog", "highlight-dialog", "/showcase/highlight-dialog"},
       {"Ignore List", "ignore-list-dialog", "/showcase/ignore-list-dialog"},
       {"Invite Dialog", "invite-dialog", "/showcase/invite-dialog"},
       {"Kick Dialog", "kick-dialog", "/showcase/kick-dialog"},
       {"Nick Change", "nick-change-dialog", "/showcase/nick-change-dialog"},
       {"Notify List", "notify-list", "/showcase/notify-list"},
       {"Options Dialog", "options-dialog", "/showcase/options-dialog"},
       {"Paste Confirm", "paste-confirm-dialog", "/showcase/paste-confirm-dialog"},
       {"Perform Dialog", "perform-dialog", "/showcase/perform-dialog"},
       {"Sound Settings", "sound-settings-dialog", "/showcase/sound-settings-dialog"},
       {"URL Catcher", "url-catcher", "/showcase/url-catcher"}
     ]},
    {"P2P", :icon_p2p,
     [
       {"File Transfer", "file-transfer", "/showcase/file-transfer"},
       {"Media Controls", "media-controls", "/showcase/media-controls"},
       {"P2P Lobby", "p2p-lobby", "/showcase/p2p-lobby"}
     ]},
    {"Games", :icon_joystick,
     [
       {"Arcade Frame", "arcade-frame", "/showcase/arcade-frame"},
       {"Game Canvas", "game-canvas", "/showcase/game-canvas"},
       {"Game Cards", "game-cards", "/showcase/game-cards"},
       {"Game Lobby", "game-lobby", "/showcase/game-lobby"},
       {"Solo Lobby", "solo-lobby", "/showcase/solo-lobby"}
     ]},
    {"Assets", :icon_folder,
     [
       {"Diagrams", "diagrams", "/showcase/diagrams"},
       {"Icons", "icons", "/showcase/icons"}
     ]}
  ]

  @spec showcase_layout(map()) :: Phoenix.LiveView.Rendered.t()
  def showcase_layout(assigns) do
    nav_items =
      Enum.map(@nav_items, fn {label, icon_fn, items} ->
        group_active = Enum.any?(items, fn {_, id, _} -> id == assigns.active_page end)
        {label, icon_fn, items, group_active}
      end)

    assigns = assign(assigns, :nav_items, nav_items)

    ~H"""
    <div class="min-h-screen bg-desktop font-system text-text flex flex-col">
      <.app_header logo_href="/showcase" />

      <div class="flex-1 m-2 md:m-4 md:mt-2">
        <div class="shadow-retro-window bg-surface p-1">
          <div class="bg-gradient-to-r from-primary to-highlight-light text-white px-2 py-1 font-bold text-xs flex items-center justify-between">
            <span>Component Showcase</span>
            <button
              type="button"
              class="md:hidden text-white text-xs px-1"
              onclick="document.getElementById('showcase-nav').classList.toggle('hidden')"
            >
              Menu
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
                    Design System
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
    "tabs" => :icon_tab_general,
    "accordion" => :icon_btn_down,
    "avatar" => :icon_status_user,
    "dialog" => :icon_dialog_options,
    "dropdown-menu" => :icon_btn_down,
    "breadcrumb" => :icon_btn_next,
    "pagination" => :icon_btn_prev,
    "fieldset" => :icon_group_view,
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
    "options-dialog" => :icon_dialog_options,
    "channel-dialog" => :icon_tab_channel,
    "address-book" => :icon_dialog_address_book,
    "about-dialog" => :icon_lightbulb,
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
    "ignore-list-dialog" => :icon_dialog_ignore,
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
    "ctcp-settings-dialog" => :icon_dialog_ctcp,
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
end
