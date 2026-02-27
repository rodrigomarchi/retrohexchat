defmodule RetroHexChatWeb.ShowcaseLive.Button do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Button", active_page: "button")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Button</h2>

      <.showcase_card title="Variants" description="All button style variants.">
        <div class="flex flex-wrap gap-2">
          <.button variant="default">
            <:icon><Icons.icon_btn_star /></:icon>
            Default
          </.button>
          <.button variant="secondary">
            <:icon><Icons.icon_btn_settings /></:icon>
            Secondary
          </.button>
          <.button variant="destructive">
            <:icon><Icons.icon_btn_remove /></:icon>
            Destructive
          </.button>
          <.button variant="outline">
            <:icon><Icons.icon_btn_page /></:icon>
            Outline
          </.button>
          <.button variant="ghost">
            <:icon><Icons.icon_btn_info /></:icon>
            Ghost
          </.button>
          <.button variant="link">
            <:icon><Icons.icon_btn_link /></:icon>
            Link
          </.button>
        </div>
        <.code_example>
          &lt;.button variant="default"&gt;
            &lt;:icon&gt;&lt;Icons.icon_btn_star /&gt;&lt;/:icon&gt;
            Default
          &lt;/.button&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="Sizes" description="Available button sizes.">
        <div class="flex flex-wrap items-center gap-2">
          <.button size="sm">
            <:icon><Icons.icon_btn_star /></:icon>
            Small
          </.button>
          <.button size="default">
            <:icon><Icons.icon_btn_star /></:icon>
            Default
          </.button>
          <.button size="lg">
            <:icon><Icons.icon_btn_star /></:icon>
            Large
          </.button>
          <.button size="icon">
            <:icon><Icons.icon_btn_add /></:icon>
          </.button>
        </div>
        <.code_example>
          &lt;.button size="sm"&gt;&lt;:icon&gt;...&lt;/:icon&gt;Small&lt;/.button&gt;
          &lt;.button size="icon"&gt;&lt;:icon&gt;...&lt;/:icon&gt;&lt;/.button&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="States" description="Disabled state.">
        <div class="flex flex-wrap gap-2">
          <.button>
            <:icon><Icons.icon_btn_ok /></:icon>
            Normal
          </.button>
          <.button disabled>
            <:icon><Icons.icon_btn_ok /></:icon>
            Disabled
          </.button>
        </div>
        <.code_example>
          &lt;.button&gt;&lt;:icon&gt;...&lt;/:icon&gt;Normal&lt;/.button&gt;
          &lt;.button disabled&gt;&lt;:icon&gt;...&lt;/:icon&gt;Disabled&lt;/.button&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
