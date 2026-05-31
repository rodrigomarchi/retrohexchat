defmodule RetroHexChatWeb.ShowcaseLive.Chat.ConversationsContextMenuPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ConversationsContextMenu
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Conversations Context Menu"),
       active_page: "conversations-context-menu"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Conversations Context Menu")}</h2>

      <.showcase_card
        title={dgettext("showcase", "With Unread Messages")}
        description="Mark as Read is enabled when the channel has unread messages."
      >
        <div class="relative h-[220px]">
          <.conversations_context_menu
            visible={true}
            x={16}
            y={8}
            channel="#lobby"
            has_unread={true}
            is_muted={false}
          />
        </div>
        <.code_example>
          &lt;.conversations_context_menu
          visible=&#123;true&#125;
          x=&#123;120&#125;
          y=&#123;80&#125;
          channel="#lobby"
          has_unread=&#123;true&#125;
          on_action="handle_ctx_action"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Muted Channel")}
        description="When is_muted is true the toggle shows 'Unmute Channel'."
      >
        <div class="relative h-[220px]">
          <.conversations_context_menu
            visible={true}
            x={16}
            y={8}
            channel="#announcements"
            has_unread={false}
            is_muted={true}
          />
        </div>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "With Custom Items")}
        description="Additional menu entries appended after a separator via custom_items list."
      >
        <div class="relative h-[280px]">
          <.conversations_context_menu
            visible={true}
            x={16}
            y={8}
            channel="#retro"
            has_unread={true}
            is_muted={false}
            custom_items={[
              %{action: "pin_channel", label: "Pin Channel"},
              %{action: "export_log", label: "Export Log..."}
            ]}
          />
        </div>
        <.code_example>
          &lt;.conversations_context_menu
          visible=&#123;true&#125;
          channel="#retro"
          has_unread=&#123;true&#125;
          custom_items=&#123;[
          %&#123;action: "pin_channel", label: "Pin Channel"&#125;,
          %&#123;action: "export_log", label: "Export Log..."&#125;
          ]&#125;
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
