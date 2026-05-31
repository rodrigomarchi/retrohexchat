defmodule RetroHexChatWeb.ShowcaseLive.Primitives.PopoverPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Popover
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Popover"), active_page: "popover")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Popover")}</h2>

      <.showcase_card
        title={gettext("Default (Top)")}
        description="Popover that appears above the trigger."
      >
        <div class="flex justify-center py-8">
          <.popover>
            <.popover_trigger target="pop-top">
              <.button variant="outline">
                <:icon><Icons.icon_lightbulb class="w-4 h-4" /></:icon>
                {gettext("Open Popover")}
              </.button>
            </.popover_trigger>
            <.popover_content id="pop-top" side="top">
              <div class="space-y-2">
                <h4 class="font-bold text-sm">{gettext("Dimensions")}</h4>
                <p class="text-xs text-muted-foreground">
                  {gettext("Set the dimensions for the layer.")}
                </p>
              </div>
            </.popover_content>
          </.popover>
        </div>
        <.code_example>
          &lt;.popover&gt;
          &lt;.popover_trigger target="my-popover"&gt;
          &lt;.button&gt;Open&lt;/.button&gt;
          &lt;/.popover_trigger&gt;
          &lt;.popover_content id="my-popover" side="top"&gt;
          Content here
          &lt;/.popover_content&gt;
          &lt;/.popover&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("Sides")}
        description="Popover can appear on different sides of the trigger."
      >
        <div class="flex flex-wrap justify-center gap-4 py-8">
          <.popover>
            <.popover_trigger target="pop-bottom">
              <.button variant="outline" size="sm">
                <:icon><Icons.icon_btn_down class="w-4 h-4" /></:icon>
                {gettext("Bottom")}
              </.button>
            </.popover_trigger>
            <.popover_content id="pop-bottom" side="bottom">
              <p class="text-xs">{gettext("This popover opens below.")}</p>
            </.popover_content>
          </.popover>

          <.popover>
            <.popover_trigger target="pop-left">
              <.button variant="outline" size="sm">
                <:icon><Icons.icon_btn_prev class="w-4 h-4" /></:icon>
                {gettext("Left")}
              </.button>
            </.popover_trigger>
            <.popover_content id="pop-left" side="left">
              <p class="text-xs">{gettext("This popover opens to the left.")}</p>
            </.popover_content>
          </.popover>

          <.popover>
            <.popover_trigger target="pop-right">
              <.button variant="outline" size="sm">
                <:icon><Icons.icon_btn_next class="w-4 h-4" /></:icon>
                {gettext("Right")}
              </.button>
            </.popover_trigger>
            <.popover_content id="pop-right" side="right">
              <p class="text-xs">{gettext("This popover opens to the right.")}</p>
            </.popover_content>
          </.popover>
        </div>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
