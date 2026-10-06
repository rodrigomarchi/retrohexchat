defmodule RetroHexChatWeb.Components.UI.MediaSession.ReactionPicker do
  @moduledoc """
  The reactions button of a call dock and the row of reactions it opens —
  the P2P call and the group call share it.

  Each call sends a reaction its own way (a LiveView event for P2P, a data
  attribute the conference hook picks up for the group call), so every
  `:reaction` entry carries the attributes its button needs (`attrs`); the picker owns
  the popover, the buttons and the drawings.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Popover
  import RetroHexChatWeb.Components.UI.ToolButton

  alias RetroHexChatWeb.Icons.CallControls

  attr :label, :string, required: true
  attr :testid, :string, default: nil
  attr :trigger_testid, :string, default: nil
  attr :panel_testid, :string, default: nil

  slot :reaction, required: true do
    attr :key, :string, required: true, doc: "heart, thumbs_up, clap, laugh, sparkle or wow"
    attr :label, :string, required: true
    attr :testid, :string
    attr :icon_testid, :string
    attr :attrs, :list, doc: "how this call sends it: the button's phx-*/data-* attributes"
  end

  @spec reaction_picker(map()) :: Phoenix.LiveView.Rendered.t()
  def reaction_picker(assigns) do
    ~H"""
    <.popover
      label={@label}
      placement="above"
      trigger_class={tool_button_class(variant: "dock")}
      trigger_testid={@trigger_testid}
      panel_role="toolbar"
      panel_testid={@panel_testid}
      panel_class="flex gap-1 border border-border bg-surface p-1 shadow-retro-raised"
      data-testid={@testid}
    >
      <:trigger><CallControls.icon_call_reactions class="h-4 w-4" /></:trigger>
      <.tool_button
        :for={entry <- @reaction}
        label={entry.label}
        data-testid={entry[:testid]}
        {entry[:attrs] || []}
      >
        <span
          class="flex items-center justify-center"
          aria-hidden="true"
          data-testid={entry[:icon_testid]}
        >
          <.reaction_icon reaction={entry.key} class="h-4 w-4" />
        </span>
      </.tool_button>
    </.popover>
    """
  end

  @doc "The drawing of a reaction, wherever one is shown."
  attr :reaction, :string, required: true
  attr :class, :any, default: nil

  @spec reaction_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def reaction_icon(assigns) do
    ~H"""
    <CallControls.icon_call_reaction_heart :if={@reaction == "heart"} class={@class} />
    <CallControls.icon_call_reaction_thumbs_up :if={@reaction == "thumbs_up"} class={@class} />
    <CallControls.icon_call_reaction_clap :if={@reaction == "clap"} class={@class} />
    <CallControls.icon_call_reaction_laugh :if={@reaction == "laugh"} class={@class} />
    <CallControls.icon_call_reaction_sparkle :if={@reaction in ["sparkle", "wow"]} class={@class} />
    """
  end
end
