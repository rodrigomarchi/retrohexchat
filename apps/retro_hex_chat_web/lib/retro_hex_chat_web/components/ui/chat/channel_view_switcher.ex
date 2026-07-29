defmodule RetroHexChatWeb.Components.UI.ChannelViewSwitcher do
  @moduledoc """
  Conversation-toolbar controls for switching between chat, space and conference.

  The host LiveView derives the active call read model. This component only
  renders the controls and emits the existing events.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.GroupCall.ChannelBadge

  alias RetroHexChatWeb.Icons

  attr :channel_view, :atom, default: :chat
  attr :active_channel, :string, default: nil
  attr :show_status_tab, :boolean, default: false
  attr :call_active, :boolean, default: false
  attr :call_current, :boolean, default: false
  attr :call_summary, :map, default: nil
  attr :identified, :boolean, default: true

  @spec channel_view_switcher(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_view_switcher(assigns) do
    ~H"""
    <div class="flex shrink-0 items-center gap-px" data-testid="channel-view-switcher">
      <.view_button
        view={:chat}
        active={@channel_view == :chat}
        label={dgettext("chat", "Chat")}
        title={dgettext("chat", "Chat")}
      >
        <Icons.icon_chat class="h-3.5 w-3.5 shrink-0" />
      </.view_button>
      <.view_button
        view={:space}
        active={@channel_view == :space}
        label={dgettext("chat", "Space")}
        title={dgettext("chat", "Space")}
      >
        <Icons.icon_community class="h-3.5 w-3.5 shrink-0" />
      </.view_button>
      <.group_call_channel_entry
        :if={@active_channel && !@show_status_tab}
        channel={@active_channel}
        active={@call_active}
        current={@call_current}
        identified={@identified}
        summary={@call_summary}
      />
    </div>
    """
  end

  attr :view, :atom, required: true
  attr :active, :boolean, default: false
  attr :label, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  defp view_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="switch_channel_view"
      phx-value-view={Atom.to_string(@view)}
      class={[
        "conversation-toolbar-button flex shrink-0 items-center justify-center p-0 shadow-retro-raised bg-surface text-xs",
        "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
        @active && "bg-canvas font-bold shadow-retro-sunken"
      ]}
      aria-label={@label}
      title={@title}
      aria-pressed={@active}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
end
