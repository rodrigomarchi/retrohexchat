defmodule RetroHexChatWeb.ShowcaseLive.ConversationsPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Conversations
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Conversations",
       active_page: "conversations"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Conversations</h2>

      <.showcase_card
        title="Full Sidebar"
        description="Conversations sidebar with channels (multiple states), private messages, users, and popular channels."
      >
        <div class="max-w-[220px] shadow-retro-field bg-white">
          <.conversations
            channels={["#lobby", "#help", "#random", "#dev", "#music"]}
            active_channel="#lobby"
            unread_channels={["#help", "#random"]}
            highlight_channels={["#random"]}
            muted_channels={["#music"]}
            pm_conversations={["alice", "bob", "carol"]}
            active_pm="bob"
            unread_pms={["alice"]}
            channel_users={[
              %{nick: "admin", role: :owner},
              %{nick: "moderator", role: :operator},
              %{nick: "helper", role: :half_operator},
              %{nick: "speaker", role: :voiced},
              %{nick: "lurker", role: nil}
            ]}
            popular_channels={["#gaming", "#music", "#sports"]}
          />
        </div>
        <.code_example>
          &lt;.conversations
            channels=&#123;["#lobby", "#help", "#random"]&#125;
            active_channel="#lobby"
            unread_channels=&#123;["#help"]&#125;
            highlight_channels=&#123;["#random"]&#125;
            muted_channels=&#123;["#music"]&#125;
            pm_conversations=&#123;["alice", "bob"]&#125;
            active_pm="bob"
            unread_pms=&#123;["alice"]&#125;
            channel_users=&#123;[
              %&#123;nick: "admin", role: :owner&#125;,
              %&#123;nick: "mod", role: :operator&#125;
            ]&#125;
            popular_channels=&#123;["#gaming"]&#125;
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Empty State"
        description="When no channels or PMs are available."
      >
        <div class="max-w-[220px] shadow-retro-field bg-white">
          <.conversations />
        </div>
      </.showcase_card>

      <.showcase_card
        title="Channels Only"
        description="Sidebar with channels but no private messages or popular channels."
      >
        <div class="max-w-[220px] shadow-retro-field bg-white">
          <.conversations
            channels={["#general", "#announcements"]}
            active_channel="#general"
          />
        </div>
      </.showcase_card>

      <.showcase_card
        title="Channel States"
        description="Visual states: normal, active (selected bg), unread (bold + badge), highlight (red text + bold), muted (50% opacity)."
      >
        <div class="max-w-[220px] shadow-retro-field bg-white">
          <.conversations
            channels={["#normal", "#active", "#unread", "#highlight", "#muted"]}
            active_channel="#active"
            unread_channels={["#unread", "#highlight"]}
            highlight_channels={["#highlight"]}
            muted_channels={["#muted"]}
          />
        </div>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
