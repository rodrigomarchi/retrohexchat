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

  alias RetroHexChat.Chat.UnreadTracker
  alias RetroHexChatWeb.Icons

  attr :conversations_open, :boolean, default: false

  attr :conversations_unread, :integer,
    default: 0,
    doc: "Unread across every conversation; the drawer's own rail is not rendered on a phone"

  attr :nicklist_open, :boolean, default: false
  attr :show_sidebar_toggles, :boolean, default: true
  attr :sidebar_toggles_class, :any, default: nil
  attr :active_channel, :string, default: nil
  attr :active_pm, :string, default: nil
  attr :show_status_tab, :boolean, default: false

  attr :unread_boundary_id, :any,
    default: nil,
    doc: "First line the reader had not seen; the jump button exists only while there is one"

  attr :pinned_count, :integer,
    default: 0,
    doc: "How many lines this channel keeps; the button exists only while there is one"

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
        <%!-- The drawer's rail carries this count on a desktop, and a phone has
              no rail: below the stacking breakpoint this button is the only
              thing left that can say another conversation is waiting. --%>
        <.action_button
          event="toggle_conversations"
          active={@conversations_open}
          badge={@conversations_unread}
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

      <%!-- Only while there is somewhere to jump to. A button that scrolls to
            where you already are is a button that teaches people to ignore
            the toolbar. --%>
      <%!-- Only where there is something to show. A channel that keeps nothing
            has no list worth opening, and a button that opens an empty window
            is the kind that teaches people to ignore the toolbar. --%>
      <.action_button
        :if={@pinned_count > 0}
        event="open_pinned_dialog"
        active={false}
        text={dgettext("chat", "Pinned (%{count})", count: @pinned_count)}
        label={dgettext("chat", "Show the messages this channel keeps")}
        testid="conversation-toolbar-pinned"
      >
        <Icons.icon_btn_set_topic class="h-4 w-4" />
      </.action_button>

      <.action_button
        :if={@unread_boundary_id}
        event="jump_to_first_unread"
        active={false}
        text={dgettext("chat", "First unread")}
        label={dgettext("chat", "Jump to the first message you have not read")}
        testid="conversation-toolbar-first-unread"
      >
        <Icons.icon_btn_down class="h-4 w-4" />
      </.action_button>

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
  attr :badge, :integer, default: 0, doc: "Count to ride on the glyph; 0 draws nothing"
  attr :testid, :string, required: true
  attr :rest, :global
  slot :inner_block, required: true

  defp action_button(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "conversation-toolbar-button relative bg-surface inline-flex shrink-0 items-center justify-center",
        "active:shadow-retro-sunken",
        if(@active, do: "shadow-retro-sunken bg-hover-bg", else: "shadow-retro-raised")
      ]}
      phx-click={@event}
      title={describe(@label, @badge)}
      aria-pressed={to_string(@active)}
      data-testid={@testid}
      {@rest}
    >
      {render_slot(@inner_block)}
      <span class="conversation-toolbar-button__text">{@text}</span>
      <span
        :if={@badge > 0}
        class="conversation-toolbar-button__badge"
        data-testid={"#{@testid}-badge"}
        aria-hidden="true"
      >
        {UnreadTracker.display_count(@badge)}
      </span>
    </button>
    """
  end

  # The count says itself in the tooltip rather than in an aria-label, because
  # the visible text is this button's accessible name and an aria-label would
  # take that job away from it. Where the text is hidden — the phone width where
  # the badge exists at all — the title is what a screen reader falls back to,
  # so the count reaches both readings without a second name competing.
  defp describe(label, badge) when is_integer(badge) and badge > 0 do
    label <>
      " — " <>
      dngettext("chat", "%{count} unread", "%{count} unread", badge, count: badge)
  end

  defp describe(label, _badge), do: label
end
