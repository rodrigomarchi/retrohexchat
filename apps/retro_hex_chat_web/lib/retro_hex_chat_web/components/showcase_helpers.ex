defmodule RetroHexChatWeb.ShowcaseHelpers do
  @moduledoc false
  use Phoenix.Component

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
       {"Tokens & Typography", "index", "/showcase"}
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
       {"Avatar", "avatar", "/showcase/avatar"}
     ]},
    {"Data", nil,
     [
       {"Table", "table", "/showcase/table"}
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
                <div class="px-2 py-1 mt-2 first:mt-0 text-xs font-bold text-muted-foreground">
                  {group_label}
                </div>
                <.link
                  :for={{label, id, path} <- items}
                  navigate={path}
                  class={[
                    "block px-2 py-1 text-xs cursor-pointer",
                    if(@active_page == id,
                      do: "bg-primary text-white font-bold",
                      else: "hover:bg-primary hover:text-white"
                    )
                  ]}
                >
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
end
