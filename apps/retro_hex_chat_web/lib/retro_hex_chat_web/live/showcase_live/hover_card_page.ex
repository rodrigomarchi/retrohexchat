defmodule RetroHexChatWeb.ShowcaseLive.HoverCardPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.HoverCard
  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Hover Card", active_page: "hover-card")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Hover Card</h2>

      <.showcase_card
        title="Full Info Card"
        description="Hover card with all nick info fields, role badges, channels, and contact status."
      >
        <.hover_card
          nick="CoolUser42"
          away="brb lunch"
          host="cool@user.example.com"
          online_since="3h 42m"
          client="RetroHexChat v2.1"
          channels={["#lobby", "#dev", "#music"]}
          is_contact={true}
        >
          <:role_badges>
            <.badge variant="destructive">Owner</.badge>
            <.badge variant="default">Operator</.badge>
          </:role_badges>
        </.hover_card>
        <.code_example>
          &lt;.hover_card
            nick="CoolUser42"
            away="brb lunch"
            host="cool@user.example.com"
            online_since="3h 42m"
            client="RetroHexChat v2.1"
            channels={["#lobby", "#dev"]}
            is_contact={true}
          &gt;
            &lt;:role_badges&gt;
              &lt;.badge variant="destructive"&gt;Owner&lt;/.badge&gt;
            &lt;/:role_badges&gt;
          &lt;/.hover_card&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Minimal Card"
        description="Just nick and host — no roles, channels, or status."
      >
        <.hover_card nick="guest123" host="guest@webchat.example.com" />
      </.showcase_card>

      <.showcase_card
        title="Ignored User"
        description="Card showing ignored status badge."
      >
        <.hover_card
          nick="spammer"
          host="bad@actor.net"
          is_ignored={true}
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
