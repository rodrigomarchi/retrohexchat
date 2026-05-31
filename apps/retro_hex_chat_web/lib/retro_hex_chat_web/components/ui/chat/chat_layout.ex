defmodule RetroHexChatWeb.Components.UI.ChatLayout do
  @moduledoc """
  Chat layout component for the showcase design system.

  Composed from conversations + tab_bar + chat_message + nicklist + toolbar
  + chat_input + topic_bar primitives. Full MDI composition.

  ## Usage

      <.chat_layout
        channels={["#lobby", "#help"]}
        active_channel="#lobby"
        messages={[%{nick: "alice", text: "Hello!"}]}
        users={[%{nick: "alice", role: "op"}]}
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Conversations
  import RetroHexChatWeb.Components.UI.TabBar
  import RetroHexChatWeb.Components.UI.TopicBar
  import RetroHexChatWeb.Components.UI.ChatMessage
  import RetroHexChatWeb.Components.UI.Nicklist
  import RetroHexChatWeb.Components.UI.ChatInput

  @doc "Renders the full chat layout."
  attr :channels, :list, default: ["#lobby"]
  attr :active_channel, :string, default: "#lobby"
  attr :topic, :string, default: ""
  attr :messages, :list, default: []
  attr :users, :list, default: []
  attr :class, :string, default: nil
  attr :rest, :global

  @spec chat_layout(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_layout(assigns) do
    tabs =
      [%{type: :status, label: dgettext("chat", "Status")}] ++
        Enum.map(assigns.channels, fn ch ->
          %{type: :channel, label: ch, active: ch == assigns.active_channel}
        end)

    assigns = assign(assigns, :tabs, tabs)

    ~H"""
    <div
      class={classes(["flex h-[300px] md:h-[500px] shadow-retro-window bg-surface", @class])}
      {@rest}
    >
      <%!-- Sidebar --%>
      <div class="hidden md:flex md:w-[200px] md:shrink-0 border-r border-border flex-col">
        <.conversations
          channels={@channels}
          active_channel={@active_channel}
          class="flex-1"
        />
      </div>

      <%!-- Main area --%>
      <div class="flex-1 flex flex-col min-w-0">
        <%!-- Tab bar --%>
        <.tab_bar tabs={@tabs} />

        <%!-- Topic bar --%>
        <.topic_bar
          variant="channel"
          channel_name={@active_channel}
          topic={@topic}
        />

        <%!-- Chat + Nicklist --%>
        <div class="flex flex-1 min-h-0">
          <%!-- Messages --%>
          <.chat_message_list class="flex-1">
            <.chat_message
              :for={msg <- @messages}
              timestamp={Map.get(msg, :timestamp)}
              nick={msg.nick}
              nick_color={Map.get(msg, :nick_color)}
              type={Map.get(msg, :type, "normal")}
            >
              {msg.text}
            </.chat_message>
          </.chat_message_list>

          <%!-- Nicklist --%>
          <.nicklist class="hidden md:flex md:w-[140px] md:shrink-0">
            <.nicklist_item
              :for={u <- @users}
              nick={u.nick}
              role={Map.get(u, :role, "normal")}
              status={Map.get(u, :status, "online")}
            />
          </.nicklist>
        </div>

        <%!-- Input --%>
        <.chat_input />
      </div>
    </div>
    """
  end
end
