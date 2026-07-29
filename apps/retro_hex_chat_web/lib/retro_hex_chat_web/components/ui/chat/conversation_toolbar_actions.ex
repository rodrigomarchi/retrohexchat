defmodule RetroHexChatWeb.Components.UI.ConversationToolbarActions do
  @moduledoc """
  Primary chat-surface actions shared by desktop and stacked layouts.

  These controls belong to the conversation toolbar, not to the IRC tab strip:
  they toggle the conversations sidebar, the nicklist sidebar and the in-chat
  search panel, then expose one context action for the active conversation. The
  parent owns the visible state and passes it in so the buttons can expose a
  pressed state consistently on desktop and mobile.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :conversations_open, :boolean, default: false
  attr :nicklist_open, :boolean, default: false
  attr :search_open, :boolean, default: false
  attr :active_channel, :string, default: nil
  attr :active_pm, :string, default: nil
  attr :show_status_tab, :boolean, default: false
  attr :class, :any, default: nil

  @spec conversation_toolbar_actions(map()) :: Phoenix.LiveView.Rendered.t()
  def conversation_toolbar_actions(assigns) do
    assigns =
      assigns
      |> assign(
        :show_channel_context,
        !assigns.show_status_tab && is_binary(assigns.active_channel) &&
          !is_binary(assigns.active_pm)
      )
      |> assign(:show_pm_context, !assigns.show_status_tab && is_binary(assigns.active_pm))

    ~H"""
    <div
      class={classes(["flex shrink-0 items-center gap-1", @class])}
      data-testid="conversation-toolbar-actions"
    >
      <.action_button
        event="toggle_conversations"
        active={@conversations_open}
        label={dgettext("chat", "Show conversations")}
        testid="conversation-toolbar-conversations"
      >
        <Icons.icon_btn_toggle_conversations class="h-4 w-4" />
      </.action_button>
      <.action_button
        event="toggle_nicklist"
        active={@nicklist_open}
        label={dgettext("chat", "Show nicklist")}
        testid="conversation-toolbar-nicklist"
      >
        <Icons.icon_btn_toggle_nicklist class="h-4 w-4" />
      </.action_button>
      <.action_button
        event="toggle_search"
        active={@search_open}
        label={dgettext("chat", "Find in chat")}
        testid="conversation-toolbar-search"
      >
        <Icons.icon_btn_find class="h-4 w-4" />
      </.action_button>

      <span
        :if={@show_channel_context || @show_pm_context}
        class="mx-[1px] h-6 w-[1px] shrink-0 bg-gray-500"
        aria-hidden="true"
        data-testid="conversation-toolbar-context-separator"
      />

      <.action_button
        :if={@show_channel_context}
        event="open_channel_central"
        active={false}
        label={dgettext("chat", "Channel settings")}
        testid="conversation-toolbar-channel-central"
      >
        <Icons.icon_btn_channel_central class="h-4 w-4" />
      </.action_button>

      <.action_button
        :if={@show_pm_context}
        event="open_user_lookup"
        active={false}
        label={dgettext("chat", "User lookup")}
        testid="conversation-toolbar-user-lookup"
        phx-value-nickname={@active_pm}
      >
        <Icons.icon_btn_search class="h-4 w-4" />
      </.action_button>
    </div>
    """
  end

  attr :event, :string, required: true
  attr :active, :boolean, default: false
  attr :label, :string, required: true
  attr :testid, :string, required: true
  attr :rest, :global
  slot :inner_block, required: true

  defp action_button(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "conversation-toolbar-button bg-surface inline-flex h-6 w-6 shrink-0 items-center justify-center p-0",
        "focus:outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-black",
        "active:shadow-retro-sunken",
        if(@active, do: "shadow-retro-sunken bg-hover-bg", else: "shadow-retro-raised")
      ]}
      phx-click={@event}
      title={@label}
      aria-label={@label}
      aria-pressed={to_string(@active)}
      data-testid={@testid}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
end
