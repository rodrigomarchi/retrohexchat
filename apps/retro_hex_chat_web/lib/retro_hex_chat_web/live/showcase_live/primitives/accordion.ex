defmodule RetroHexChatWeb.ShowcaseLive.Primitives.Accordion do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Accordion
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Accordion"), active_page: "accordion")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Accordion")}</h2>

      <.showcase_card title={gettext("Usage")} description="Vertically collapsing content panels.">
        <div class="max-w-sm">
          <.accordion>
            <.accordion_item>
              <.accordion_trigger group="showcase">
                <:icon><Icons.icon_chat class="w-4 h-4" /></:icon>
                {gettext("What is RetroHexChat?")}
              </.accordion_trigger>
              <.accordion_content>
                <p class="text-sm">
                  {gettext("A retro-styled chat application built with Phoenix LiveView.")}
                </p>
              </.accordion_content>
            </.accordion_item>
            <.accordion_item>
              <.accordion_trigger group="showcase">
                <:icon><Icons.icon_laptop class="w-4 h-4" /></:icon>
                {gettext("Is it responsive?")}
              </.accordion_trigger>
              <.accordion_content>
                <p class="text-sm">
                  {gettext(
                    "Yes! These new UI components are built with Tailwind for full responsiveness."
                  )}
                </p>
              </.accordion_content>
            </.accordion_item>
            <.accordion_item>
              <.accordion_trigger group="showcase">
                <:icon><Icons.icon_wrench class="w-4 h-4" /></:icon>
                {gettext("Can I customize it?")}
              </.accordion_trigger>
              <.accordion_content>
                <p class="text-sm">
                  {gettext("Absolutely. All components are local source code you can modify freely.")}
                </p>
              </.accordion_content>
            </.accordion_item>
          </.accordion>
        </div>
        <.code_example>
          &lt;.accordion&gt;
          &lt;.accordion_item&gt;
          &lt;.accordion_trigger group="faq"&gt;Question?&lt;/.accordion_trigger&gt;
          &lt;.accordion_content&gt;
          &lt;p&gt;Answer here.&lt;/p&gt;
          &lt;/.accordion_content&gt;
          &lt;/.accordion_item&gt;
          &lt;/.accordion&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
