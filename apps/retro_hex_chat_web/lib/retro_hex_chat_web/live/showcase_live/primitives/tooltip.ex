defmodule RetroHexChatWeb.ShowcaseLive.Primitives.Tooltip do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Tooltip
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Tooltip", active_page: "tooltip")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Tooltip</h2>

      <.showcase_card title="Usage" description="A popup that displays information on hover.">
        <.tooltip>
          <.tooltip_trigger>
            <.button variant="outline">
              <:icon><Icons.icon_btn_info /></:icon>
              Hover me
            </.button>
          </.tooltip_trigger>
          <.tooltip_content>
            <:icon><Icons.icon_lightbulb class="w-4 h-4" /></:icon>
            <p>This is a tooltip</p>
          </.tooltip_content>
        </.tooltip>
        <.code_example>
          &lt;.tooltip&gt;
          &lt;.tooltip_trigger&gt;
          &lt;.button variant="outline"&gt;Hover me&lt;/.button&gt;
          &lt;/.tooltip_trigger&gt;
          &lt;.tooltip_content&gt;
          &lt;p&gt;This is a tooltip&lt;/p&gt;
          &lt;/.tooltip_content&gt;
          &lt;/.tooltip&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
