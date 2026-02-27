defmodule RetroHexChatWeb.ShowcaseLive.Index do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Design System", active_page: "index")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Design System</h2>

      <.showcase_card title="Colors" description="Semantic color tokens mapped to retro palette.">
        <div class="grid grid-cols-4 gap-2">
          <div :for={
            {name, class} <- [
              {"Primary", "bg-primary text-white"},
              {"Secondary", "bg-secondary"},
              {"Destructive", "bg-destructive text-white"},
              {"Surface", "bg-surface"},
              {"Desktop", "bg-desktop text-white"},
              {"Accent", "bg-accent"},
              {"Muted", "bg-muted"},
              {"Canvas BG", "bg-canvas-bg text-canvas-fg"}
            ]
          }>
            <div class={["p-2 text-xs text-center shadow-retro-raised", class]}>
              {name}
            </div>
          </div>
        </div>
      </.showcase_card>

      <.showcase_card title="Typography" description="Font sizes using Source Code Pro monospace.">
        <div class="space-y-2">
          <p class="text-xs">text-xs — 12px — Caption text</p>
          <p class="text-sm">text-sm — 14px — Small text</p>
          <p class="text-base">text-base — 16px — Body text</p>
          <p class="text-lg">text-lg — 18px — Large text</p>
          <p class="text-xl">text-xl — 22px — Heading</p>
          <p class="text-2xl">text-2xl — 26px — Title</p>
        </div>
        <.code_example>
          &lt;p class="text-xs"&gt;Caption text&lt;/p&gt;
          &lt;p class="text-base"&gt;Body text&lt;/p&gt;
          &lt;p class="text-xl"&gt;Heading&lt;/p&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="Spacing" description="Retro spacing tokens (retro-1 through retro-32).">
        <div class="space-y-1">
          <div :for={
            {name, class} <- [
              {"retro-1 (1px)", "w-[1px]"},
              {"retro-2 (2px)", "w-[2px]"},
              {"retro-4 (4px)", "w-retro-4"},
              {"retro-8 (8px)", "w-retro-8"},
              {"retro-16 (16px)", "w-retro-16"},
              {"retro-24 (24px)", "w-retro-24"},
              {"retro-32 (32px)", "w-retro-32"}
            ]
          }>
            <div class="flex items-center gap-2">
              <div class={["h-3 bg-primary", class]} />
              <span class="text-xs">{name}</span>
            </div>
          </div>
        </div>
        <.code_example>
          &lt;div class="p-retro-8"&gt;8px padding&lt;/div&gt;
          &lt;div class="m-retro-16"&gt;16px margin&lt;/div&gt;
          &lt;div class="gap-retro-4"&gt;4px gap&lt;/div&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Shadows (3D Borders)"
        description="Win98-style inset box shadows for retro depth."
      >
        <div class="grid grid-cols-2 gap-3">
          <div :for={
            {name, class} <- [
              {"shadow-retro-raised", "shadow-retro-raised"},
              {"shadow-retro-sunken", "shadow-retro-sunken"},
              {"shadow-retro-window", "shadow-retro-window"},
              {"shadow-retro-field", "shadow-retro-field"},
              {"shadow-retro-status", "shadow-retro-status"},
              {"shadow-retro-tab", "shadow-retro-tab"}
            ]
          }>
            <div class={["bg-surface p-3 text-xs text-center", class]}>
              {name}
            </div>
          </div>
        </div>
        <.code_example>
          &lt;div class="shadow-retro-raised bg-surface p-3"&gt;Raised&lt;/div&gt;
          &lt;div class="shadow-retro-sunken bg-surface p-3"&gt;Sunken&lt;/div&gt;
          &lt;div class="shadow-retro-window bg-surface p-3"&gt;Window&lt;/div&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
