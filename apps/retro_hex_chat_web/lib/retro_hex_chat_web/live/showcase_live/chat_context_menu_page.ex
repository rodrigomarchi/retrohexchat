defmodule RetroHexChatWeb.ShowcaseLive.ChatContextMenuPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ChatContextMenu
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Chat Context Menu", active_page: :chat_context_menu)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Chat Context Menu</h2>

      <.showcase_card
        title="Nick Menu"
        description="Right-click on a nickname. Shows PM, Whois, Copy, Ignore, Address Book, P2P actions (when identified), and Op actions (when viewer is op)."
      >
        <div class="flex gap-6 flex-wrap">
          <div>
            <p class="text-xs font-bold mb-2 text-muted-foreground">Basic (regular user)</p>
            <div class="relative inline-block">
              <.chat_context_menu
                visible
                x={0}
                y={0}
                type={:nick}
                target_nick="Brutus"
                viewer_nick="Troll"
                viewer_is_identified={false}
                viewer_is_op={false}
                is_target_self={false}
                is_target_ignored={false}
                class="!fixed-none !static"
              />
            </div>
          </div>
          <div>
            <p class="text-xs font-bold mb-2 text-muted-foreground">
              Identified user (P2P actions)
            </p>
            <div class="relative inline-block">
              <.chat_context_menu
                visible
                x={0}
                y={0}
                type={:nick}
                target_nick="Patches"
                viewer_nick="Troll"
                viewer_is_identified
                viewer_is_op={false}
                is_target_self={false}
                is_target_ignored={false}
                class="!fixed-none !static"
              />
            </div>
          </div>
          <div>
            <p class="text-xs font-bold mb-2 text-muted-foreground">Op viewer (full menu)</p>
            <div class="relative inline-block">
              <.chat_context_menu
                visible
                x={0}
                y={0}
                type={:nick}
                target_nick="Reginald"
                viewer_nick="Troll"
                viewer_is_identified
                viewer_is_op
                is_target_self={false}
                is_target_ignored={false}
                class="!fixed-none !static"
              />
            </div>
          </div>
        </div>
        <.code_example>
          &lt;.chat_context_menu
          visible
          type=&#123;:nick&#125; target_nick="Brutus"
          viewer_nick="Troll"
          viewer_is_identified
          viewer_is_op
          on_action="handle_ctx_action"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Nick Menu — Edge Cases"
        description="Self-targeting (Ignore disabled) and ignored user (Unignore shown)."
      >
        <div class="flex gap-6 flex-wrap">
          <div>
            <p class="text-xs font-bold mb-2 text-muted-foreground">Self target</p>
            <div class="relative inline-block">
              <.chat_context_menu
                visible
                x={0}
                y={0}
                type={:nick}
                target_nick="Troll"
                viewer_nick="Troll"
                viewer_is_identified
                viewer_is_op={false}
                is_target_self
                is_target_ignored={false}
                class="!fixed-none !static"
              />
            </div>
          </div>
          <div>
            <p class="text-xs font-bold mb-2 text-muted-foreground">Ignored user</p>
            <div class="relative inline-block">
              <.chat_context_menu
                visible
                x={0}
                y={0}
                type={:nick}
                target_nick="Spammer"
                viewer_nick="Troll"
                viewer_is_identified={false}
                viewer_is_op={false}
                is_target_self={false}
                is_target_ignored
                class="!fixed-none !static"
              />
            </div>
          </div>
        </div>
        <.code_example>
          &lt;.chat_context_menu type=&#123;:nick&#125; target_nick="Troll" is_target_self /&gt;
          &lt;.chat_context_menu type=&#123;:nick&#125; target_nick="Spammer" is_target_ignored /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="URL Menu"
        description="Right-click on a URL in chat. Open, Copy, or Save to URL list."
      >
        <div class="relative inline-block">
          <.chat_context_menu
            visible
            x={0}
            y={0}
            type={:url}
            target_url="https://example.com/article"
            class="!fixed-none !static"
          />
        </div>
        <.code_example>
          &lt;.chat_context_menu
          visible
          type=&#123;:url&#125; target_url="https://example.com/article"
          on_action="handle_ctx_action"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Channel Menu"
        description="Right-click on a #channel name. Join (disabled if already joined), Copy, Info."
      >
        <div class="flex gap-6 flex-wrap">
          <div>
            <p class="text-xs font-bold mb-2 text-muted-foreground">Not joined</p>
            <div class="relative inline-block">
              <.chat_context_menu
                visible
                x={0}
                y={0}
                type={:channel}
                target_channel="#elixir"
                is_already_joined={false}
                class="!fixed-none !static"
              />
            </div>
          </div>
          <div>
            <p class="text-xs font-bold mb-2 text-muted-foreground">Already joined</p>
            <div class="relative inline-block">
              <.chat_context_menu
                visible
                x={0}
                y={0}
                type={:channel}
                target_channel="#lobby"
                is_already_joined
                class="!fixed-none !static"
              />
            </div>
          </div>
        </div>
        <.code_example>
          &lt;.chat_context_menu type=&#123;:channel&#125; target_channel="#elixir" /&gt;
          &lt;.chat_context_menu type=&#123;:channel&#125; target_channel="#lobby" is_already_joined /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Message Menu"
        description="Right-click on a message body. Copy, Reply, Delete (own messages only), Ignore Sender."
      >
        <div class="flex gap-6 flex-wrap">
          <div>
            <p class="text-xs font-bold mb-2 text-muted-foreground">Own message</p>
            <div class="relative inline-block">
              <.chat_context_menu
                visible
                x={0}
                y={0}
                type={:message}
                target_message={
                  %{id: "msg-1", text: "Hello world!", nick: "Troll", has_urls: false, is_own: true}
                }
                viewer_nick="Troll"
                is_target_self
                class="!fixed-none !static"
              />
            </div>
          </div>
          <div>
            <p class="text-xs font-bold mb-2 text-muted-foreground">Other user's message</p>
            <div class="relative inline-block">
              <.chat_context_menu
                visible
                x={0}
                y={0}
                type={:message}
                target_message={
                  %{
                    id: "msg-2",
                    text: "Check this out!",
                    nick: "Brutus",
                    has_urls: true,
                    is_own: false
                  }
                }
                viewer_nick="Troll"
                is_target_self={false}
                class="!fixed-none !static"
              />
            </div>
          </div>
        </div>
        <.code_example>
          &lt;.chat_context_menu
          type=&#123;:message&#125; target_message=&#123;%&#123;
          id: "msg-1",
          text: "Hello!",
          nick: "Troll",
          has_urls: false,
          is_own: true
          &#125;&#125; viewer_nick="Troll"
          is_target_self
          on_action="handle_ctx_action"
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
