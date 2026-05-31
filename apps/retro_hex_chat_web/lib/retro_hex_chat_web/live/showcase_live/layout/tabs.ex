defmodule RetroHexChatWeb.ShowcaseLive.Layout.Tabs do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Tabs
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: dgettext("showcase", "Tabs"), active_page: "tabs")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Tabs")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Usage")}
        description="A set of layered sections of content. Uses the builder pattern."
      >
        <.tabs :let={builder} id="showcase-tabs" default="tab1">
          <.tabs_list>
            <.tabs_trigger builder={builder} value="tab1">
              <:icon><Icons.icon_tab_general /></:icon>
              {dgettext("showcase", "Account")}
            </.tabs_trigger>
            <.tabs_trigger builder={builder} value="tab2">
              <:icon><Icons.icon_tab_modes /></:icon>
              {dgettext("showcase", "Password")}
            </.tabs_trigger>
            <.tabs_trigger builder={builder} value="tab3">
              <:icon><Icons.icon_btn_settings /></:icon>
              {dgettext("showcase", "Settings")}
            </.tabs_trigger>
          </.tabs_list>
          <.tabs_content value="tab1">
            <p class="text-sm p-4">{dgettext("showcase", "Manage your account settings here.")}</p>
          </.tabs_content>
          <.tabs_content value="tab2">
            <p class="text-sm p-4">{dgettext("showcase", "Change your password here.")}</p>
          </.tabs_content>
          <.tabs_content value="tab3">
            <p class="text-sm p-4">{dgettext("showcase", "Configure application settings.")}</p>
          </.tabs_content>
        </.tabs>
        <.code_example>
          &lt;.tabs :let=&#123;builder&#125; id="my-tabs" default="tab1"&gt;
          &lt;.tabs_list&gt;
          &lt;.tabs_trigger builder=&#123;builder&#125; value="tab1"&gt;
          &lt;:icon&gt;&lt;Icons.icon_tab_general /&gt;&lt;/:icon&gt;
          Account
          &lt;/.tabs_trigger&gt;
          &lt;/.tabs_list&gt;
          &lt;.tabs_content value="tab1"&gt;
          &lt;p&gt;Account content&lt;/p&gt;
          &lt;/.tabs_content&gt;
          &lt;/.tabs&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
