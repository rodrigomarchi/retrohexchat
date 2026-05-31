defmodule RetroHexChatWeb.ShowcaseLive.Shell.EmptyStatePage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.EmptyState
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Empty State"), active_page: "empty-state")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Empty State")}</h2>

      <.showcase_card
        title={gettext("Basic")}
        description="Empty state with icon, title, and description."
      >
        <div class="shadow-retro-field bg-white">
          <.empty_state>
            <:icon><Icons.icon_chat class="w-8 h-8" /></:icon>
            <:title>{gettext("No messages yet")}</:title>
            <:description>{gettext("Start a conversation to see messages here.")}</:description>
          </.empty_state>
        </div>
        <.code_example>
          &lt;.empty_state&gt;
          &lt;:icon&gt;&lt;Icons.icon_chat class="w-8 h-8" /&gt;&lt;/:icon&gt;
          &lt;:title&gt;No messages yet&lt;/:title&gt;
          &lt;:description&gt;Start a conversation.&lt;/:description&gt;
          &lt;/.empty_state&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("With Action")}
        description="Empty state with a call-to-action button."
      >
        <div class="shadow-retro-field bg-white">
          <.empty_state>
            <:icon><Icons.icon_channels class="w-8 h-8" /></:icon>
            <:title>{gettext("No channels joined")}</:title>
            <:description>
              {gettext("Browse available channels and join one to start chatting.")}
            </:description>
            <:action>
              <.button variant="outline" size="sm">
                <:icon><Icons.icon_btn_channel_list class="w-4 h-4" /></:icon>
                {gettext("Browse Channels")}
              </.button>
            </:action>
          </.empty_state>
        </div>
        <.code_example>
          &lt;.empty_state&gt;
          &lt;:icon&gt;&lt;Icons.icon_channels class="w-8 h-8" /&gt;&lt;/:icon&gt;
          &lt;:title&gt;No channels joined&lt;/:title&gt;
          &lt;:description&gt;Browse and join a channel.&lt;/:description&gt;
          &lt;:action&gt;
          &lt;.button variant="outline" size="sm"&gt;Browse&lt;/.button&gt;
          &lt;/:action&gt;
          &lt;/.empty_state&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("Variations")}
        description="Different icons and contexts for empty states."
      >
        <div class="grid grid-cols-2 gap-4">
          <div class="shadow-retro-field bg-white">
            <.empty_state>
              <:icon><Icons.icon_btn_search class="w-8 h-8" /></:icon>
              <:title>{gettext("No results")}</:title>
              <:description>{gettext("Try a different search term.")}</:description>
            </.empty_state>
          </div>
          <div class="shadow-retro-field bg-white">
            <.empty_state>
              <:icon><Icons.icon_tab_contacts class="w-8 h-8" /></:icon>
              <:title>{gettext("No contacts")}</:title>
              <:description>{gettext("Add users to your address book.")}</:description>
            </.empty_state>
          </div>
        </div>
        <.code_example>
          &lt;.empty_state&gt;
          &lt;:icon&gt;&lt;Icons.icon_btn_search class="w-8 h-8" /&gt;&lt;/:icon&gt;
          &lt;:title&gt;No results&lt;/:title&gt;
          &lt;:description&gt;Try different terms.&lt;/:description&gt;
          &lt;/.empty_state&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
