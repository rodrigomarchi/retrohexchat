defmodule RetroHexChatWeb.Components.UI.Space.ConversationEntry do
  @moduledoc """
  The way into the space of the conversation on screen.

  Two shapes and no third, which is what makes this simpler than the conference
  beside it: a space is a *place*, so there is nothing to create and its address
  is good whether anybody is standing in it or not. Either this person already
  has that address open — and the entry is a way to the tab holding it, because
  a second tab of a world you are in is a second character nobody asked for — or
  it is an anchor that opens one.

  It carries no count. How many people are inside is on the card in the
  conversation, which has a feed for exactly that and pays for it only while a
  card is on screen; a badge here would be a second subscription to the same
  roster for the same fact.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Icons

  attr :space_id, :string, required: true
  attr :class, :any, default: nil

  attr :open_paths, :any,
    default: nil,
    doc: "the addresses this person already has open, from `Live.OpenSurfaces`"

  @spec space_conversation_entry(map()) :: Phoenix.LiveView.Rendered.t()
  def space_conversation_entry(assigns) do
    assigns = assign(assigns, :path, Paths.space_path(assigns.space_id))

    ~H"""
    <div class={classes(["conversation-toolbar-entry flex items-center gap-px", @class])}>
      <.link
        :if={open?(@open_paths, @path)}
        href={@path}
        id={"space-tab-#{@space_id}"}
        phx-hook="SurfaceTabLinkHook"
        data-surface-path={@path}
        class={entry_class()}
        title={dgettext("chat", "This space is open in another tab — click to go to it")}
        data-testid="space-elsewhere"
        data-space={@space_id}
      >
        <Icons.icon_toolbar_community class="h-3.5 w-3.5 shrink-0" />
        <span class="conversation-toolbar-button__text">{dgettext("chat", "In another tab")}</span>
      </.link>

      <.link
        :if={!open?(@open_paths, @path)}
        href={@path}
        target="_blank"
        rel="noopener"
        class={entry_class()}
        title={dgettext("chat", "Enter the space in a tab of its own")}
        data-testid="space-open"
        data-space={@space_id}
      >
        <Icons.icon_toolbar_community class="h-3.5 w-3.5 shrink-0" />
        <span class="conversation-toolbar-button__text">{dgettext("chat", "Space")}</span>
      </.link>
    </div>
    """
  end

  defp entry_class do
    [
      "conversation-toolbar-button flex shrink-0 items-center justify-center shadow-retro-raised bg-surface text-xs",
      "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
    ]
  end

  defp open?(%MapSet{} = paths, path), do: MapSet.member?(paths, path)
  defp open?(_paths, _path), do: false
end
