defmodule RetroHexChatWeb.ShowcaseLive.Chat.ChatLayoutPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ChatLayout
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Chat Layout"),
       active_page: "chat-layout",
       messages: [
         %{
           timestamp: "14:20",
           nick: "alice",
           text: gettext("Hey everyone!"),
           nick_color: "text-blue-600"
         },
         %{
           timestamp: "14:21",
           nick: "bob",
           text: gettext("Hi alice! How's it going?"),
           nick_color: "text-green-600"
         },
         %{
           timestamp: "14:22",
           nick: "carol",
           text: gettext("Welcome to #lobby!"),
           nick_color: "text-red-600"
         },
         %{
           timestamp: "14:23",
           nick: "alice",
           text: gettext("Pretty good, working on some code"),
           nick_color: "text-blue-600"
         },
         %{timestamp: "14:24", nick: "dave", text: gettext("Anyone up for a game?")},
         %{
           timestamp: "14:25",
           nick: "bob",
           text: gettext("Sure! What game?"),
           nick_color: "text-green-600"
         },
         %{
           timestamp: "14:25",
           nick: gettext("System"),
           text: gettext("eve has joined #lobby"),
           type: "system"
         }
       ],
       users: [
         %{nick: "alice", role: "op", status: "online"},
         %{nick: "bob", role: "voice", status: "online"},
         %{nick: "carol", role: "normal", status: "online"},
         %{nick: "dave", role: "normal", status: "away"},
         %{nick: "eve", role: "normal", status: "online"}
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Chat Layout")}</h2>

      <.showcase_card
        title={gettext("Full MDI Layout")}
        description="Complete chat interface: sidebar + tabs + topic + messages + nicklist + input."
      >
        <.chat_layout
          channels={["#lobby", "#help", "#dev"]}
          active_channel="#lobby"
          topic="Welcome to RetroHexChat! Please read the rules."
          messages={@messages}
          users={@users}
        />
        <.code_example>
          &lt;.chat_layout
          channels=&#123;["#lobby", "#help"]&#125;
          active_channel="#lobby"
          topic="Welcome!"
          messages=&#123;@messages&#125;
          users=&#123;@users&#125;
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
