defmodule RetroHexChatWeb.ShowcaseLive.Chat.AutocompletePage do
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
        title="Command Mode"
        description="Autocomplete dropdown with command suggestions (default mode)."
      >
        <.autocomplete
          mode={:command}
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
          mode=&#123;:command&#125;
          items=&#123;[%&#123;category: "Commands", label: "/join", description: "Join a channel"&#125;]&#125;
          selected_index=&#123;0&#125;
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Nick Mode"
        description="Autocomplete showing nick suggestions with online status dots."
      >
        <.autocomplete
          mode={:nick}
          items={[
            %{category: "Nicks", label: "alice", online: true},
            %{category: "Nicks", label: "alice_away", online: false},
            %{category: "Nicks", label: "aliceinwonderland", online: true}
          ]}
          selected_index={1}
        />
      </.showcase_card>

      <.showcase_card
        title="Channel Mode"
        description="Autocomplete showing channels with joined checkmark and user counts."
      >
        <.autocomplete
          mode={:channel}
          items={[
            %{category: "Channels", label: "#general", description: "42 users", joined: true},
            %{category: "Channels", label: "#gaming", description: "18 users", joined: false},
            %{category: "Channels", label: "#help", description: "7 users", joined: true},
            %{category: "Channels", label: "#random", description: "31 users", joined: false}
          ]}
          selected_index={0}
        />
      </.showcase_card>

      <.showcase_card
        title="Subcommand Mode"
        description="Autocomplete for subcommands (e.g., /set options)."
      >
        <.autocomplete
          mode={:subcommand}
          items={[
            %{category: "Settings", label: "theme", description: "Change color theme"},
            %{category: "Settings", label: "font", description: "Change font size"},
            %{category: "Settings", label: "timestamps", description: "Toggle timestamps"}
          ]}
          selected_index={2}
        />
      </.showcase_card>

      <.showcase_card
        title="Empty State"
        description="Autocomplete with no matching results."
      >
        <.autocomplete items={[]} />
      </.showcase_card>

      <.showcase_card
        title="Hidden"
        description="Autocomplete with visible=false (nothing renders)."
      >
        <div class="text-xs text-muted-foreground italic p-2">
          (autocomplete is hidden — nothing rendered below)
        </div>
        <.autocomplete visible={false} items={[%{label: "test"}]} />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
