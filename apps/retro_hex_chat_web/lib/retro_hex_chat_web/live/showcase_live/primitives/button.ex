defmodule RetroHexChatWeb.ShowcaseLive.Primitives.Button do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: dgettext("showcase", "Button"), active_page: "button")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Button")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Variants")}
        description="All button style variants."
      >
        <div class="flex flex-wrap gap-2">
          <.button variant="default">
            <:icon><Icons.icon_btn_star /></:icon>
            {dgettext("showcase", "Default")}
          </.button>
          <.button variant="secondary">
            <:icon><Icons.icon_btn_settings /></:icon>
            {dgettext("showcase", "Secondary")}
          </.button>
          <.button variant="destructive">
            <:icon><Icons.icon_btn_remove /></:icon>
            {dgettext("showcase", "Destructive")}
          </.button>
          <.button variant="outline">
            <:icon><Icons.icon_btn_page /></:icon>
            {dgettext("showcase", "Outline")}
          </.button>
          <.button variant="ghost">
            <:icon><Icons.icon_btn_info /></:icon>
            {dgettext("showcase", "Ghost")}
          </.button>
          <.button variant="link">
            <:icon><Icons.icon_btn_link /></:icon>
            {dgettext("showcase", "Link")}
          </.button>
        </div>
        <.code_example>
          &lt;.button variant="default"&gt;
          &lt;:icon&gt;&lt;Icons.icon_btn_star /&gt;&lt;/:icon&gt;
          Default
          &lt;/.button&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title={dgettext("showcase", "Sizes")} description="Available button sizes.">
        <div class="flex flex-wrap items-center gap-2">
          <.button size="sm">
            <:icon><Icons.icon_btn_star /></:icon>
            {dgettext("showcase", "Small")}
          </.button>
          <.button size="default">
            <:icon><Icons.icon_btn_star /></:icon>
            {dgettext("showcase", "Default")}
          </.button>
          <.button size="lg">
            <:icon><Icons.icon_btn_star /></:icon>
            {dgettext("showcase", "Large")}
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

      <.showcase_card title={dgettext("showcase", "States")} description="Disabled state.">
        <div class="flex flex-wrap gap-2">
          <.button>
            <:icon><Icons.icon_btn_ok /></:icon>
            {dgettext("showcase", "Normal")}
          </.button>
          <.button disabled>
            <:icon><Icons.icon_btn_ok /></:icon>
            {dgettext("showcase", "Disabled")}
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
