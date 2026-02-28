defmodule RetroHexChatWeb.ShowcaseLive.Chat.HoverCardPage do
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
          real_name="Cool Person"
          away="brb lunch"
          host="cool@user.example.com"
          server="irc.retro.chat"
          online_since="3h 42m"
          online_for="2d 14h"
          idle="5m"
          client="RetroHexChat v2.1"
          registered={true}
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
          real_name="Cool Person"
          registered=&#123;true&#125;
          host="cool@user.example.com"
          online_for="2d 14h"
          idle="5m"
          channels=&#123;["#lobby", "#dev"]&#125;
          is_contact=&#123;true&#125;
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Loading State"
        description="Hover card in loading state while WHOIS data is being fetched."
      >
        <.hover_card nick="unknown_user" loading={true} />
      </.showcase_card>

      <.showcase_card
        title="Role Badge (via role attr)"
        description="Hover card using the role atom attr instead of the role_badges slot."
      >
        <.hover_card
          nick="ChannelOp"
          host="op@admin.net"
          role={:operator}
          registered={true}
        />
      </.showcase_card>

      <.showcase_card
        title="Bot User"
        description="Hover card for a bot with the :bot role."
      >
        <.hover_card
          nick="ChanBot"
          host="bot@services.local"
          role={:bot}
          client="Bot Engine 1.0"
          channels={["#lobby", "#help"]}
        />
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
