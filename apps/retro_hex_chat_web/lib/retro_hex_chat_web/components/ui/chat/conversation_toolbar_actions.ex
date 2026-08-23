defmodule RetroHexChatWeb.Components.UI.ConversationToolbarActions do
  @moduledoc """
  Conversation actions that ride at the end of the tab strip.

  What is left here opens something beside the conversation — a drawer, a
  dialog — rather than switching what the conversation region shows. Anything
  that switches that region is a tab. Find is not here at all: it lives in the
  menu bar, the Start menu and Ctrl+Shift+F, and a fourth entry point cost a
  button without buying reach.

  Each one carries its label in the open. They sit in the same strip as the
  tabs, at the same text size, so an icon alone would read as decoration next
  to three labelled tabs.

  The parent owns the visible state and passes it in so the buttons can expose a
  pressed state consistently on desktop and mobile.

  The two sidebar toggles sit in their own cluster so a layout can scope them to
  the widths where they are the way into a sidebar: the desktop keeps a 36px
  rail for that, a phone cannot spare the column and reaches the drawers from
  here instead.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :conversations_open, :boolean, default: false
  attr :nicklist_open, :boolean, default: false
  attr :show_sidebar_toggles, :boolean, default: true
  attr :sidebar_toggles_class, :any, default: nil
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
      <div
        :if={@show_sidebar_toggles}
        class={classes(["flex shrink-0 items-center gap-1", @sidebar_toggles_class])}
        data-testid="conversation-toolbar-sidebar-toggles"
      >
        <.action_button
          event="toggle_conversations"
          active={@conversations_open}
          text={dgettext("chat", "Conversations")}
          label={dgettext("chat", "Show conversations")}
          testid="conversation-toolbar-conversations"
        >
          <Icons.icon_toolbar_toggle_conversations class="h-4 w-4" />
        </.action_button>
        <.action_button
          event="toggle_nicklist"
          active={@nicklist_open}
          text={dgettext("chat", "Users")}
          label={dgettext("chat", "Show nicklist")}
          testid="conversation-toolbar-nicklist"
        >
          <Icons.icon_toolbar_toggle_nicklist class="h-4 w-4" />
        </.action_button>
      </div>
      <span
        :if={@show_sidebar_toggles && (@show_channel_context || @show_pm_context)}
        class="conversation-toolbar-separator"
        aria-hidden="true"
        data-testid="conversation-toolbar-context-separator"
      />

      <.action_button
        :if={@show_channel_context}
        event="open_channel_central"
        active={false}
        text={dgettext("chat", "Channel Central")}
        label={dgettext("chat", "Channel settings")}
        testid="conversation-toolbar-channel-central"
      >
        <Icons.icon_toolbar_channel_central class="h-4 w-4" />
      </.action_button>

      <.action_button
        :if={@show_pm_context}
        event="open_user_lookup"
        active={false}
        text={dgettext("chat", "User Lookup")}
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
  attr :text, :string, required: true, doc: "Visible label — also the accessible name"
  attr :label, :string, required: true, doc: "Longer description for the tooltip"
  attr :testid, :string, required: true
  attr :rest, :global
  slot :inner_block, required: true

  defp action_button(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "conversation-toolbar-button bg-surface inline-flex shrink-0 items-center justify-center",
        "focus:outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-black",
        "active:shadow-retro-sunken",
        if(@active, do: "shadow-retro-sunken bg-hover-bg", else: "shadow-retro-raised")
      ]}
      phx-click={@event}
      title={@label}
      aria-pressed={to_string(@active)}
      data-testid={@testid}
      {@rest}
    >
      {render_slot(@inner_block)}
      <span class="conversation-toolbar-button__text">{@text}</span>
    </button>
    """
  end
end
