defmodule RetroHexChatWeb.ShowcaseLive.Chat.ConversationsPage do
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
        description="Conversations sidebar with channels (multiple states), private messages, users, and popular channels. Includes user counts, disconnected indicator, role sorting, and SVG role badges."
      >
        <div class="max-w-[220px] shadow-retro-field bg-white">
          <.conversations
            id="demo-full"
            channels={["#lobby", "#help", "#random", "#dev", "#music"]}
            active_channel="#lobby"
            unread_channels={["#help", "#random"]}
            unread_counts={%{"#help" => 3, "#random" => 15, "alice" => 2}}
            highlight_channels={["#random"]}
            flash_channels={["#random"]}
            muted_channels={["#music"]}
            disconnected_channels={["#dev"]}
            channel_user_counts={
              %{"#lobby" => 12, "#help" => 5, "#random" => 28, "#dev" => 3, "#music" => 8}
            }
            pm_conversations={["alice", "bob", "carol"]}
            active_pm="bob"
            unread_pms={["alice"]}
            channel_users={[
              %{nick: "admin", role: :owner},
              %{nick: "moderator", role: :operator},
              %{nick: "helper", role: :half_operator},
              %{nick: "speaker", role: :voiced},
              %{nick: "lurker", role: :regular},
              %{nick: "chanbot", role: :bot},
              %{nick: "afk_user", role: :regular, away: true}
            ]}
            popular_channels={[
              %{name: "#gaming", user_count: 45},
              %{name: "#sports", user_count: 22},
              %{name: "#movies", user_count: 18}
            ]}
          />
        </div>
        <.code_example>
          &lt;.conversations
          channels=&#123;["#lobby", "#help"]&#125;
          active_channel="#lobby"
          unread_counts=&#123;%&#123;"#help" =&gt; 3&#125;&#125;
          channel_user_counts=&#123;%&#123;"#lobby" =&gt; 12&#125;&#125;
          disconnected_channels=&#123;["#dev"]&#125;
          on_channel_click="switch_channel"
          on_close="toggle_conversations"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Empty State"
        description="When no channels or PMs are available. Shows 'Browse channels' button when on_browse_channels is set."
      >
        <div class="max-w-[220px] shadow-retro-field bg-white">
          <.conversations id="demo-empty" on_browse_channels="open_channel_list" />
        </div>
      </.showcase_card>

      <.showcase_card
        title="Channels Only"
        description="Sidebar with channels but no private messages or popular channels."
      >
        <div class="max-w-[220px] shadow-retro-field bg-white">
          <.conversations
            id="demo-channels"
            channels={["#general", "#announcements"]}
            active_channel="#general"
            channel_user_counts={%{"#general" => 34, "#announcements" => 12}}
          />
        </div>
      </.showcase_card>

      <.showcase_card
        title="Channel States"
        description="Visual states: normal, active (selected bg), unread (bold + badge), highlight (red + bold), muted (50% opacity), disconnected (⚡), flash (pulse animation)."
      >
        <div class="max-w-[220px] shadow-retro-field bg-white">
          <.conversations
            id="demo-states"
            channels={["#normal", "#active", "#unread", "#highlight", "#muted", "#disconnected"]}
            active_channel="#active"
            unread_channels={["#unread", "#highlight"]}
            unread_counts={%{"#unread" => 5, "#highlight" => 42}}
            highlight_channels={["#highlight"]}
            muted_channels={["#muted"]}
            disconnected_channels={["#disconnected"]}
          />
        </div>
      </.showcase_card>

      <.showcase_card
        title="User Roles"
        description="Users sorted by role priority (owner > operator > halfop > voiced > regular > bot). Each role has SVG badge + color. Away users are dimmed."
      >
        <div class="max-w-[220px] shadow-retro-field bg-white">
          <.conversations
            id="demo-roles"
            channels={["#staff"]}
            active_channel="#staff"
            channel_users={[
              %{nick: "regular_user", role: :regular},
              %{nick: "the_owner", role: :owner},
              %{nick: "bot_service", role: :bot},
              %{nick: "voiced_user", role: :voiced},
              %{nick: "op_admin", role: :operator},
              %{nick: "halfop_mod", role: :half_operator},
              %{nick: "away_person", role: :regular, away: true}
            ]}
          />
        </div>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
