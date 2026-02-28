defmodule RetroHexChatWeb.ShowcaseHelpers do
  @moduledoc false
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  @doc "Full-page showcase wrapper with sidebar navigation and content area."
  attr :active_page, :string, required: true
  slot :inner_block, required: true

  @nav_items [
    {"Design System", nil,
     [
       {"Tokens", "index", "/showcase"}
     ]},
    {"Form", nil,
     [
       {"Button", "button", "/showcase/button"},
       {"Input", "input", "/showcase/input"},
       {"Label", "label", "/showcase/label"},
       {"Textarea", "textarea", "/showcase/textarea"},
       {"Select", "select", "/showcase/select"},
       {"Checkbox", "checkbox", "/showcase/checkbox"},
       {"Radio Group", "radio-group", "/showcase/radio-group"},
       {"Switch", "switch", "/showcase/switch"},
       {"Slider", "slider", "/showcase/slider"},
       {"Toggle", "toggle", "/showcase/toggle"},
       {"Toggle Group", "toggle-group", "/showcase/toggle-group"}
     ]},
    {"Feedback", nil,
     [
       {"Alert", "alert", "/showcase/alert"},
       {"Badge", "badge", "/showcase/badge"},
       {"Progress", "progress", "/showcase/progress"},
       {"Skeleton", "skeleton", "/showcase/skeleton"},
       {"Tooltip", "tooltip", "/showcase/tooltip"},
       {"Toast", "toast", "/showcase/toast"},
       {"Context Menu", "context-menu", "/showcase/context-menu"},
       {"Loading Spinner", "loading-spinner", "/showcase/loading-spinner"},
       {"Empty State", "empty-state", "/showcase/empty-state"},
       {"Color Picker", "color-picker", "/showcase/color-picker"},
       {"Scroll Area", "scroll-area", "/showcase/scroll-area"},
       {"Scroll Loader", "scroll-loader", "/showcase/scroll-loader"},
       {"History Search", "history-search", "/showcase/history-search"}
     ]},
    {"Layout", nil,
     [
       {"Card", "card", "/showcase/card"},
       {"Separator", "separator", "/showcase/separator"},
       {"Tabs", "tabs", "/showcase/tabs"},
       {"Accordion", "accordion", "/showcase/accordion"},
       {"Avatar", "avatar", "/showcase/avatar"},
       {"Dialog", "dialog", "/showcase/dialog"},
       {"Dropdown Menu", "dropdown-menu", "/showcase/dropdown-menu"},
       {"Breadcrumb", "breadcrumb", "/showcase/breadcrumb"},
       {"Pagination", "pagination", "/showcase/pagination"},
       {"Fieldset", "fieldset", "/showcase/fieldset"}
     ]},
    {"Data", nil,
     [
       {"Table", "table", "/showcase/table"}
     ]},
    {"Win98 Shell", nil,
     [
       {"Window", "window", "/showcase/window"},
       {"Menu", "menu", "/showcase/menu"},
       {"Toolbar", "toolbar", "/showcase/toolbar"},
       {"Status Bar", "status-bar", "/showcase/status-bar"},
       {"Toolbar App", "toolbar-app", "/showcase/toolbar-app"},
       {"Status Bar App", "status-bar-app", "/showcase/status-bar-app"},
       {"App Header", "app-header", "/showcase/app-header"}
     ]},
    {"Chat", nil,
     [
       {"IRC Tabs", "irc-tabs", "/showcase/irc-tabs"},
       {"Chat Message", "chat-message", "/showcase/chat-message"},
       {"Chat Input", "chat-input", "/showcase/chat-input"},
       {"Tree View", "tree-view", "/showcase/tree-view"},
       {"Nicklist", "nicklist", "/showcase/nicklist"},
       {"Game Cards", "game-cards", "/showcase/game-cards"},
       {"Conversations", "conversations", "/showcase/conversations"},
       {"Hover Card", "hover-card", "/showcase/hover-card"},
       {"Search Bar", "search-bar", "/showcase/search-bar"},
       {"Topic Bar", "topic-bar", "/showcase/topic-bar"},
       {"Formatting Toolbar", "formatting-toolbar", "/showcase/formatting-toolbar"},
       {"Emoji Picker", "emoji-picker", "/showcase/emoji-picker"},
       {"Autocomplete", "autocomplete", "/showcase/autocomplete"},
       {"Tab Bar", "tab-bar", "/showcase/tab-bar"},
       {"Reply Bar", "reply-bar", "/showcase/reply-bar"},
       {"Connection Status", "connection-status", "/showcase/connection-status"},
       {"Conversations Ctx Menu", "conversations-context-menu",
        "/showcase/conversations-context-menu"},
       {"Chat Context Menu", "chat-context-menu", "/showcase/chat-context-menu"},
       {"Syntax Tooltip", "syntax-tooltip", "/showcase/syntax-tooltip"}
     ]},
    {"Specialized", nil,
     [
       {"P2P Lobby", "p2p-lobby", "/showcase/p2p-lobby"},
       {"Media Controls", "media-controls", "/showcase/media-controls"},
       {"File Transfer", "file-transfer", "/showcase/file-transfer"},
       {"Chat Layout", "chat-layout", "/showcase/chat-layout"},
       {"Game Canvas", "game-canvas", "/showcase/game-canvas"},
       {"Game Lobby", "game-lobby", "/showcase/game-lobby"},
       {"Solo Lobby", "solo-lobby", "/showcase/solo-lobby"},
       {"Arcade Frame", "arcade-frame", "/showcase/arcade-frame"}
     ]},
    {"Dialogs", nil,
     [
       {"Confirm Dialog", "confirm-dialog", "/showcase/confirm-dialog"},
       {"Options Dialog", "options-dialog", "/showcase/options-dialog"},
       {"Channel Dialog", "channel-dialog", "/showcase/channel-dialog"},
       {"Address Book", "address-book", "/showcase/address-book"},
       {"About Dialog", "about-dialog", "/showcase/about-dialog"},
       {"Channel List", "channel-list", "/showcase/channel-list"},
       {"Highlight Dialog", "highlight-dialog", "/showcase/highlight-dialog"},
       {"Config Form", "config-form", "/showcase/config-form"},
       {"Kick Dialog", "kick-dialog", "/showcase/kick-dialog"},
       {"Delete Confirm", "delete-confirm-dialog", "/showcase/delete-confirm-dialog"},
       {"Disconnect Confirm", "disconnect-confirm-dialog", "/showcase/disconnect-confirm-dialog"},
       {"Alias Dialog", "alias-dialog", "/showcase/alias-dialog"},
       {"Flood Protection", "flood-protection-dialog", "/showcase/flood-protection-dialog"},
       {"Ignore List", "ignore-list-dialog", "/showcase/ignore-list-dialog"},
       {"Notify List", "notify-list", "/showcase/notify-list"},
       {"URL Catcher", "url-catcher", "/showcase/url-catcher"},
       {"Auto Respond", "auto-respond-dialog", "/showcase/auto-respond-dialog"},
       {"Custom Menus", "custom-menus-dialog", "/showcase/custom-menus-dialog"},
       {"Sound Settings", "sound-settings-dialog", "/showcase/sound-settings-dialog"},
       {"Invite Dialog", "invite-dialog", "/showcase/invite-dialog"},
       {"Paste Confirm", "paste-confirm-dialog", "/showcase/paste-confirm-dialog"},
       {"CTCP Settings", "ctcp-settings-dialog", "/showcase/ctcp-settings-dialog"},
       {"Cheatsheet", "cheatsheet-dialog", "/showcase/cheatsheet-dialog"},
       {"Nick Change", "nick-change-dialog", "/showcase/nick-change-dialog"},
       {"Perform Dialog", "perform-dialog", "/showcase/perform-dialog"},
       {"Channel Central", "channel-central-dialog", "/showcase/channel-central-dialog"}
     ]},
    {"Assets", nil,
     [
       {"Icons", "icons", "/showcase/icons"},
       {"Diagrams", "diagrams", "/showcase/diagrams"}
     ]}
  ]

  def showcase_layout(assigns) do
    assigns = assign(assigns, :nav_items, @nav_items)

    ~H"""
    <div class="min-h-screen bg-desktop font-system text-text">
      <div class="m-4">
        <div class="shadow-retro-window bg-surface p-1">
          <div class="bg-gradient-to-r from-primary to-highlight-light text-white px-2 py-1 font-bold text-xs">
            RetroHexChat — Component Showcase
          </div>

          <div class="flex p-1">
            <nav
              class="shadow-retro-sunken bg-white w-44 mr-2 p-1 shrink-0 overflow-y-auto"
              style="max-height: calc(100vh - 80px)"
            >
              <div :for={{group_label, _group_id, items} <- @nav_items}>
                <div class="flex items-center gap-1 px-2 py-1 mt-2 first:mt-0 text-xs font-bold text-muted-foreground">
                  <.nav_group_icon group={group_label} />
                  {group_label}
                </div>
                <.link
                  :for={{label, id, path} <- items}
                  navigate={path}
                  class={[
                    "flex items-center gap-1 px-2 py-1 text-xs cursor-pointer",
                    if(@active_page == id,
                      do: "bg-primary text-white font-bold",
                      else: "hover:bg-primary hover:text-white"
                    )
                  ]}
                >
                  <.nav_item_icon id={id} />
                  {label}
                </.link>
              </div>
            </nav>

            <div
              class="shadow-retro-sunken bg-gray-100 flex-1 p-3 overflow-y-auto"
              style="max-height: calc(100vh - 80px)"
            >
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

  # ── Nav group icons ──────────────────────────────────────

  attr :group, :string, required: true

  defp nav_group_icon(%{group: "Design System"} = assigns) do
    ~H'<Icons.icon_palette class="w-[16px] h-[16px] flex-shrink-0" />'
  end

  defp nav_group_icon(%{group: "Form"} = assigns) do
    ~H'<Icons.icon_btn_edit class="w-[16px] h-[16px] flex-shrink-0" />'
  end

  defp nav_group_icon(%{group: "Feedback"} = assigns) do
    ~H'<Icons.icon_lightbulb class="w-[16px] h-[16px] flex-shrink-0" />'
  end

  defp nav_group_icon(%{group: "Layout"} = assigns) do
    ~H'<Icons.icon_group_view class="w-[16px] h-[16px] flex-shrink-0" />'
  end

  defp nav_group_icon(%{group: "Data"} = assigns) do
    ~H'<Icons.icon_database class="w-[16px] h-[16px] flex-shrink-0" />'
  end

  defp nav_group_icon(%{group: "Win98 Shell"} = assigns) do
    ~H'<Icons.icon_laptop class="w-[16px] h-[16px] flex-shrink-0" />'
  end

  defp nav_group_icon(%{group: "Chat"} = assigns) do
    ~H'<Icons.icon_chat class="w-[16px] h-[16px] flex-shrink-0" />'
  end

  defp nav_group_icon(%{group: "Specialized"} = assigns) do
    ~H'<Icons.icon_p2p class="w-[16px] h-[16px] flex-shrink-0" />'
  end

  defp nav_group_icon(%{group: "Dialogs"} = assigns) do
    ~H'<Icons.icon_dialog_options class="w-[16px] h-[16px] flex-shrink-0" />'
  end

  defp nav_group_icon(%{group: "Assets"} = assigns) do
    ~H'<Icons.icon_folder class="w-[16px] h-[16px] flex-shrink-0" />'
  end

  defp nav_group_icon(assigns), do: ~H""

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
    <span :if={@icon_fn} class="w-4 h-4 flex-shrink-0 inline-flex items-center justify-center">
      {apply(Icons, @icon_fn, [%{class: "w-3 h-3"}])}
    </span>
    """
  end
end
