defmodule RetroHexChatWeb.ShowcaseLive.Primitives.PopoverPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Popover
  import RetroHexChatWeb.Components.UI.ToolButton
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: dgettext("showcase", "Popover"), active_page: "popover")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Popover")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Default (Top)")}
        description="Popover that appears above the trigger."
      >
        <div class="flex justify-center py-8">
          <.popover
            label={dgettext("showcase", "Open Popover")}
            placement="above-start"
            trigger_class={tool_button_class(size: "sm", captioned: true)}
            panel_class="w-64 border border-border bg-surface p-2 shadow-retro-raised"
          >
            <:trigger>
              <Icons.icon_lightbulb class="h-4 w-4" />
              <span class="tool-button__caption">{dgettext("showcase", "Open Popover")}</span>
            </:trigger>
            <div class="space-y-2">
              <h4 class="font-bold text-sm">{dgettext("showcase", "Dimensions")}</h4>
              <p class="text-xs text-muted-foreground">
                {dgettext("showcase", "Set the dimensions for the layer.")}
              </p>
            </div>
          </.popover>
        </div>
        <.code_example>
          &lt;.popover label="Open" placement="above-start" trigger_class={tool_button_class(
            size: "sm"
          )}&gt;
          &lt;:trigger&gt;&lt;Icons.icon_lightbulb /&gt;&lt;/:trigger&gt;
          Content here
          &lt;/.popover&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Sides")}
        description="Popover can appear on different sides of the trigger."
      >
        <div class="flex flex-wrap justify-center gap-4 py-8">
          <.popover
            label={dgettext("showcase", "Bottom")}
            placement="below-start"
            trigger_class={tool_button_class(size: "sm", captioned: true)}
            panel_class="w-64 border border-border bg-surface p-2 shadow-retro-raised"
          >
            <:trigger>
              <Icons.icon_btn_down class="h-4 w-4" />
              <span class="tool-button__caption">{dgettext("showcase", "Bottom")}</span>
            </:trigger>
            <p class="text-xs">{dgettext("showcase", "This popover opens below.")}</p>
          </.popover>

          <.popover
            label={dgettext("showcase", "Left")}
            placement="below-end"
            trigger_class={tool_button_class(size: "sm", captioned: true)}
            panel_class="w-64 border border-border bg-surface p-2 shadow-retro-raised"
          >
            <:trigger>
              <Icons.icon_btn_prev class="h-4 w-4" />
              <span class="tool-button__caption">{dgettext("showcase", "Left")}</span>
            </:trigger>
            <p class="text-xs">{dgettext("showcase", "This popover opens to the left.")}</p>
          </.popover>

          <.popover
            label={dgettext("showcase", "Right")}
            placement="above"
            trigger_class={tool_button_class(size: "sm", captioned: true)}
            panel_class="w-64 border border-border bg-surface p-2 shadow-retro-raised"
          >
            <:trigger>
              <Icons.icon_btn_next class="h-4 w-4" />
              <span class="tool-button__caption">{dgettext("showcase", "Right")}</span>
            </:trigger>
            <p class="text-xs">{dgettext("showcase", "This popover opens to the right.")}</p>
          </.popover>
        </div>
      </.showcase_card>
    </.showcase_layout>
    """
  end

  # A showcase page renders the component and nothing behind it, so the
  # controls it draws have nowhere to go. Answering them is what keeps a
  # click from taking the page down with an unmatched event.
  @impl true
  def handle_event(_event, _params, socket), do: {:noreply, socket}
end
