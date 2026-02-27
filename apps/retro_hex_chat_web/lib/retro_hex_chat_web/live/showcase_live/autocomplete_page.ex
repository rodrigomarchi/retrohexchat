defmodule RetroHexChatWeb.ShowcaseLive.AutocompletePage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Autocomplete
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Autocomplete", active_page: "autocomplete")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Autocomplete</h2>

      <.showcase_card
        title="Commands"
        description="Autocomplete dropdown with command suggestions."
      >
        <.autocomplete
          items={[
            %{category: "Commands", label: "/join", description: "Join a channel"},
            %{category: "Commands", label: "/part", description: "Leave current channel"},
            %{category: "Commands", label: "/msg", description: "Send a private message"},
            %{category: "Commands", label: "/nick", description: "Change your nickname"},
            %{category: "Commands", label: "/quit", description: "Disconnect from server"}
          ]}
          selected_index={0}
        />
        <.code_example>
          &lt;.autocomplete
            items=&#123;[
              %&#123;category: "Commands", label: "/join", description: "Join a channel"&#125;,
              %&#123;category: "Commands", label: "/part", description: "Leave current channel"&#125;
            ]&#125;
            selected_index=&#123;0&#125;
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Nicks"
        description="Autocomplete showing nick suggestions."
      >
        <.autocomplete
          items={[
            %{category: "Nicks", label: "alice"},
            %{category: "Nicks", label: "alice_away"},
            %{category: "Nicks", label: "aliceinwonderland"}
          ]}
          selected_index={1}
        />
      </.showcase_card>

      <.showcase_card
        title="Mixed Categories"
        description="Autocomplete with both channels and nicks."
      >
        <.autocomplete
          items={[
            %{category: "Channels", label: "#general", description: "42 users"},
            %{category: "Channels", label: "#gaming", description: "18 users"},
            %{category: "Nicks", label: "gamemaster"},
            %{category: "Nicks", label: "gamer42"}
          ]}
          selected_index={2}
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
