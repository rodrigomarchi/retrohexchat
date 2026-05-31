defmodule RetroHexChatWeb.ShowcaseLive.Chat.TabBarPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.TabBar
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Tab Bar"), active_page: "tab-bar")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Tab Bar")}</h2>

      <.showcase_card
        title={gettext("Mixed Tabs")}
        description="Status, channel, and PM tabs with various states."
      >
        <.tab_bar tabs={[
          %{type: :status, label: "Status", active: false},
          %{type: :channel, label: "#lobby", active: true},
          %{type: :channel, label: "#help", unread: true},
          %{type: :channel, label: "#dev"},
          %{type: :pm, label: "alice", unread: true},
          %{type: :pm, label: "bob"}
        ]} />
        <.code_example>
          &lt;.tab_bar tabs=&#123;[
          %&#123;type: :status, label: "Status"&#125;,
          %&#123;type: :channel, label: "#lobby", active: true&#125;,
          %&#123;type: :pm, label: "alice", unread: true&#125;
          ]&#125; /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("Status Only")}
        description="Just the status tab."
      >
        <.tab_bar tabs={[
          %{type: :status, label: "Status", active: true}
        ]} />
      </.showcase_card>

      <.showcase_card
        title={gettext("Many Channels")}
        description="Tab bar with many channel tabs."
      >
        <.tab_bar tabs={[
          %{type: :status, label: "Status"},
          %{type: :channel, label: "#lobby", active: true},
          %{type: :channel, label: "#help"},
          %{type: :channel, label: "#dev", unread: true},
          %{type: :channel, label: "#music"},
          %{type: :channel, label: "#gaming"},
          %{type: :channel, label: "#random", unread: true},
          %{type: :channel, label: "#announcements"}
        ]} />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
