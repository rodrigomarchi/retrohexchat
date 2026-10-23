defmodule RetroHexChatWeb.Components.UI.SavedDialog do
  @moduledoc """
  The window that answers "what did I keep?".

  A list of messages, so it is built from the pieces a list is already built
  from here, and nothing draws a message a second way. What is different from
  the Pinned window is who it belongs to: this one is one person's, so every
  row offers Remove without asking about anybody's rank.

  Each row says where the line was said — a channel or the person it was
  between — because a saved line read out of context is a sentence with no
  conversation attached. And a row whose line was deleted says so in place of
  the text: it keeps the evidence that saving worked without keeping what was
  deleted.

  ## Usage

      <.saved_panel
        id="saved-dialog"
        entries={@streams.saved}
        state={@paginated.saved}
        target={@myself}
        timezone={@timezone}
        nick_color_fn={@nick_color_fn}
      />

  The banner draws the newest kept line as a clipping with the conversation
  it came from beneath it. A stream is write-only to the component, so the
  island hands over its first row.
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

  @doc "Renders the Saved Messages window body."
  attr :id, :string, required: true
  attr :first_row, :map, default: nil, doc: "Newest row, for the banner picture"

  attr :entries, :any,
    required: true,
    doc: "The stream of saved rows; `:author_locale` on a row draws its author's flag"

  attr :state, :any, default: nil, doc: "PaginatedList.State for the list"
  attr :target, :any, default: nil
  attr :timezone, :string, default: "Etc/UTC"
  attr :nick_color_fn, :any, default: nil
  attr :on_open, :any, default: "saved_open"

  @spec saved_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def saved_panel(assigns) do
    ~H"""
    <div id={"#{@id}-panel"} class="flex h-full min-h-0 flex-col gap-retro-4">
      <.dialog_banner heading={dgettext("dialogs", "Lines you decided to keep")}>
        <:art>
          <Diagrams.diagram_dialog_preview
            kind={:ordered}
            title={dgettext("dialogs", "Saved")}
            lines={clipping_lines(@first_row)}
            label={dgettext("dialogs", "A miniature of a kept line and where it came from")}
          />
        </:art>
        <:glyph><Icons.icon_btn_star class="h-8 w-8" /></:glyph>
        {dgettext(
          "dialogs",
          "Saving keeps a copy for you alone — nobody is told, and the line stays here even if the conversation it came from is gone. Opening one takes you back to where it was said."
        )}
      </.dialog_banner>

      <.list_empty_state
        :if={State.empty?(@state)}
        icon={:chat}
        title={dgettext("dialogs", "You have not kept anything yet.")}
        text={
          dgettext(
            "dialogs",
            "Right-click a message and choose Save to keep it here. Nobody else can see what you keep, and it stays after the conversation has scrolled away."
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
        data-event="saved_load_more"
        data-has-more={to_string(State.more?(@state))}
        data-loading={to_string(State.loading?(@state))}
      >
        <.message_ref_row
          :for={{dom_id, entry} <- @entries}
          id={dom_id}
          testid={"saved-row-#{entry.id}"}
          open_testid={"saved-open-#{entry.id}"}
          author={entry.author_nickname}
          author_locale={Map.get(entry, :author_locale)}
          nick_color_fn={@nick_color_fn}
          where={where(entry)}
          at={entry.inserted_at}
          timezone={@timezone}
          text={MessageRefRow.preview(entry)}
          deleted={entry.deleted?}
          deleted_testid={"saved-deleted-#{entry.id}"}
          phx-click={@on_open}
          phx-target={@target}
          phx-value-saved_id={entry.id}
          phx-value-channel={entry.channel_name}
          phx-value-counterpart={entry.counterpart}
          phx-value-message_id={entry.message_id || entry.private_message_id}
        >
          <:footer>
            <form phx-submit="saved_note" phx-target={@target}>
              <input type="hidden" name="saved_id" value={entry.id} />
              <input
                type="text"
                name="note"
                value={entry.note}
                maxlength="200"
                class="w-full bg-white px-1 py-0.5 shadow-retro-field"
                placeholder={dgettext("dialogs", "Why you kept it (optional)")}
                aria-label={dgettext("dialogs", "Note")}
                data-testid={"saved-note-#{entry.id}"}
              />
            </form>
          </:footer>
          <:action>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="saved_remove"
              phx-target={@target}
              phx-value-saved_id={entry.id}
              data-testid={"saved-remove-#{entry.id}"}
            >
              <:icon><Icons.icon_reject class="h-4 w-4" /></:icon>
              {dgettext("dialogs", "Remove")}
            </.button>
          </:action>
        </.message_ref_row>
      </div>

      <.list_load_more_button
        :if={State.more?(@state)}
        target={@target}
        event="saved_load_more"
        loading={State.loading?(@state)}
        testid="saved-load-more"
      />
      <.list_announcer state={@state} />
      <.list_error_retry
        :if={State.error?(@state)}
        target={@target}
        on_retry="saved_load_more"
        text={dgettext("dialogs", "Could not load more saved messages.")}
      />
      <.list_end_marker :if={State.exhausted?(@state)} testid="saved-end" />
    </div>
    """
  end

  # Where the line was said. A saved line read with no conversation attached is
  # a sentence from nowhere.
  @spec where(map()) :: String.t()
  defp where(%{channel_name: channel}) when is_binary(channel), do: channel

  defp where(%{counterpart: nickname}) when is_binary(nickname) do
    dgettext("dialogs", "with %{nickname}", nickname: nickname)
  end

  defp where(_entry), do: ""

  # The newest clipping and where it was cut from.
  @spec clipping_lines(map() | nil) :: [map()]
  defp clipping_lines(nil), do: []

  defp clipping_lines(row) do
    [
      %{text: MessageRefRow.preview(row, 60), tone: :accent},
      %{text: origin_label(row), tone: :muted}
    ]
  end

  @spec origin_label(map()) :: String.t()
  defp origin_label(row) do
    case Map.get(row, :channel_name) do
      nil -> dgettext("dialogs", "kept from a private conversation")
      channel -> dgettext("dialogs", "kept from %{channel}", channel: channel)
    end
  end
end
