defmodule RetroHexChatWeb.Components.UI.PinnedDialog do
  @moduledoc """
  The window that answers "what is this channel keeping?".

  The rules, the link to the event, what was agreed — the things that scroll
  away and get retyped. It is a list of messages, so it is built from the pieces
  a list is already built from here, and nothing draws a message a second way.

  Each row goes to the line it kept, so each row is a button: everything in this
  app that goes somewhere when clicked is something the keyboard can reach. The
  Unpin beside it is a second button rather than a menu, because removing a pin
  is the one thing anybody does in this window besides reading it — and it only
  appears for somebody who may.

  ## Usage

      <.pinned_panel
        id="pinned-dialog"
        pins={@streams.pins}
        state={@paginated.pins}
        can_unpin={@can_unpin}
        target={@myself}
        timezone={@timezone}
        nick_color_fn={@nick_color_fn}
      />

  The banner draws the strip a pin occupies at the top of the room, which is
  what a pin *is*, carrying the line that is actually up there. A stream is
  write-only to the component, so the island hands over its first row.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.ListStates
  import RetroHexChatWeb.Components.UI.DialogBanner
  import RetroHexChatWeb.Components.UI.MessageRefRow, only: [message_ref_row: 1]

  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Components.UI.MessageRefRow
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PaginatedList.State

  @doc "Renders the Pinned window body."
  attr :id, :string, required: true
  attr :first_row, :map, default: nil, doc: "Newest row, for the banner picture"

  attr :pins, :any,
    required: true,
    doc: "The stream of pinned rows; `:author_locale` on a row draws its author's flag"

  attr :can_unpin, :boolean, default: false
  attr :state, :any, default: nil, doc: "PaginatedList.State for the list"
  attr :target, :any, default: nil
  attr :timezone, :string, default: "Etc/UTC"
  attr :nick_color_fn, :any, default: nil
  attr :on_open, :any, default: "pinned_open"

  @spec pinned_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def pinned_panel(assigns) do
    ~H"""
    <div id={"#{@id}-panel"} class="flex h-full min-h-0 flex-col gap-retro-4">
      <.dialog_banner heading={dgettext("dialogs", "What the channel keeps above everything")}>
        <:art>
          <Diagrams.diagram_dialog_preview
            kind={:pinned}
            title={dgettext("dialogs", "Channel")}
            lines={pin_lines(@first_row)}
            label={dgettext("dialogs", "A miniature of the room wearing its pinned line")}
          />
        </:art>
        <:glyph><Icons.icon_pin class="h-8 w-8" /></:glyph>
        {dgettext(
          "dialogs",
          "A pin belongs to the channel, not to you: everybody sees the same one, and an operator is the only one who can put a line up here or take it down."
        )}
      </.dialog_banner>

      <.list_empty_state
        :if={State.empty?(@state)}
        icon={:chat}
        title={dgettext("dialogs", "This channel is not keeping anything yet.")}
        text={
          dgettext(
            "dialogs",
            "An operator can pin a message — the rules, a link, what was agreed — and it stays findable here after it scrolls away."
          )
        }
      />

      <div
        :if={not State.empty?(@state)}
        id={"#{@id}-list"}
        class="min-h-[200px] flex-1 overflow-y-auto bg-white p-1 shadow-retro-field"
        phx-hook="InfiniteScrollHook"
        phx-update="stream"
        data-edge="bottom"
        data-target={@target}
        data-event="pinned_load_more"
        data-has-more={to_string(State.more?(@state))}
        data-loading={to_string(State.loading?(@state))}
      >
        <.message_ref_row
          :for={{dom_id, pin} <- @pins}
          id={dom_id}
          testid={"pinned-row-#{pin.message_id}"}
          open_testid={"pinned-open-#{pin.message_id}"}
          author={pin.author_nickname}
          author_locale={Map.get(pin, :author_locale)}
          nick_color_fn={@nick_color_fn}
          at={pin.inserted_at}
          timezone={@timezone}
          text={MessageRefRow.preview(pin)}
          phx-click={@on_open}
          phx-target={@target}
          phx-value-message_id={pin.message_id}
        >
          <:footer>{dgettext("dialogs", "pinned by %{nickname}", nickname: pin.pinned_by)}</:footer>
          <:action :if={@can_unpin}>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="pinned_unpin"
              phx-target={@target}
              phx-value-message_id={pin.message_id}
              data-testid={"pinned-unpin-#{pin.message_id}"}
            >
              <:icon><Icons.icon_reject class="h-4 w-4" /></:icon>
              {dgettext("dialogs", "Unpin")}
            </.button>
          </:action>
        </.message_ref_row>
      </div>

      <.list_load_more_button
        :if={State.more?(@state)}
        target={@target}
        event="pinned_load_more"
        loading={State.loading?(@state)}
        testid="pinned-load-more"
      />
      <.list_announcer state={@state} />
      <.list_error_retry
        :if={State.error?(@state)}
        target={@target}
        on_retry="pinned_load_more"
        text={dgettext("dialogs", "Could not load more pinned messages.")}
      />
      <.list_end_marker :if={State.exhausted?(@state)} testid="pinned-end" />
    </div>
    """
  end

  # What the room is actually wearing above its messages.
  @spec pin_lines(map() | nil) :: [map()]
  defp pin_lines(nil), do: []

  defp pin_lines(row) do
    [
      %{text: MessageRefRow.preview(row), tone: :accent},
      %{text: Map.get(row, :author_nickname, ""), tone: :muted}
    ]
  end
end
