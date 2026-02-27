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
       {"Tooltip", "tooltip", "/showcase/tooltip"}
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
       {"Status Bar", "status-bar", "/showcase/status-bar"}
     ]},
    {"Chat", nil,
     [
       {"IRC Tabs", "irc-tabs", "/showcase/irc-tabs"},
       {"Chat Message", "chat-message", "/showcase/chat-message"},
       {"Chat Input", "chat-input", "/showcase/chat-input"},
       {"Tree View", "tree-view", "/showcase/tree-view"},
       {"Nicklist", "nicklist", "/showcase/nicklist"},
       {"Game Cards", "game-cards", "/showcase/game-cards"}
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
    "diagrams" => :icon_code
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
