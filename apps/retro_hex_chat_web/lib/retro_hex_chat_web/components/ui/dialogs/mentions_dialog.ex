defmodule RetroHexChatWeb.Components.UI.MentionsDialog do
  @moduledoc """
  The window that answers "who has said my name?".

  It is a list of messages, so it is built from the pieces a list is already
  built from here: the five list states, the infinite-scroll hook, and the same
  nick/timestamp furniture a chat line uses. Nothing here draws a message a
  second way — a mention that looked different from the line it came from would
  be a second message renderer to keep in step.

  Each row is a button rather than a div: clicking it goes somewhere, and
  everything in this app that goes somewhere when clicked is something the
  keyboard can reach.

  ## Usage

      <.mentions_panel
        id="mentions-dialog"
        mentions={@streams.mentions}
        state={@mentions_state}
        target={@myself}
        timezone={@timezone}
        nick_color_fn={@nick_color_fn}
      />

  The banner draws the line as it was said in its channel rather than the
  rows below it. A stream is write-only to the component, so the island
  hands over its first row for the picture to use.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ListStates
  import RetroHexChatWeb.Components.UI.DialogBanner

  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PaginatedList.State

  @doc "Renders the Mentions window body."
  attr :id, :string, required: true
  attr :first_row, :map, default: nil, doc: "Newest row, for the banner picture"
  attr :mentions, :any, required: true, doc: "The stream of mention rows"
  attr :state, :any, default: nil, doc: "PaginatedList.State for the list"
  attr :target, :any, default: nil
  attr :timezone, :string, default: "Etc/UTC"
  attr :nick_color_fn, :any, default: nil
  attr :on_open, :any, default: "mentions_open"

  @spec mentions_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def mentions_panel(assigns) do
    ~H"""
    <div id={"#{@id}-panel"} class="flex h-full min-h-0 flex-col gap-retro-4">
      <.dialog_banner heading={dgettext("dialogs", "Lines that named you while you were away")}>
        <:art>
          <Diagrams.diagram_dialog_preview
            kind={:query}
            title={dgettext("dialogs", "Channel")}
            lines={mention_lines(@first_row)}
            label={dgettext("dialogs", "A miniature of a channel line naming you")}
          />
        </:art>
        <:glyph><Icons.icon_btn_bell class="h-8 w-8" /></:glyph>
        {dgettext(
          "dialogs",
          "A mention is recorded whenever somebody writes your nickname in a channel you had joined, whether or not the window was open. Opening one takes you to the line in its own conversation."
        )}
      </.dialog_banner>

      <.list_empty_state
        :if={State.empty?(@state)}
        icon={:chat}
        title={dgettext("dialogs", "Nobody has mentioned you yet.")}
        text={
          dgettext(
            "dialogs",
            "Messages that write your nickname in a channel you were in show up here."
          )
        }
      />

      <div
        :if={not State.empty?(@state)}
        id={"#{@id}-list"}
        class="min-h-[200px] flex-1 overflow-y-auto bg-white p-1 shadow-retro-field retro-scrollbar"
        phx-hook="InfiniteScrollHook"
        phx-update="stream"
        data-edge="bottom"
        data-target={@target}
        data-event="mentions_load_more"
        data-has-more={to_string(State.more?(@state))}
        data-loading={to_string(State.loading?(@state))}
      >
        <button
          :for={{dom_id, mention} <- @mentions}
          id={dom_id}
          type="button"
          class="mentions-row w-full border-b border-border p-2 text-left last:border-b-0"
          phx-click={@on_open}
          phx-target={@target}
          phx-value-channel={mention.channel_name}
          phx-value-message_id={mention.id}
          data-testid={"mention-row-#{mention.id}"}
        >
          <span class="mentions-row__head flex items-center gap-retro-4">
            <Icons.icon_channels class="h-3 w-3 shrink-0" />
            <span class="font-bold">{mention.channel_name}</span>
            <span class={["truncate", nick_class(@nick_color_fn, mention.author_nickname)]}>
              {mention.author_nickname}
            </span>
            <span class="ml-auto shrink-0 text-muted-foreground">
              {ChatHelpers.format_datetime(mention.inserted_at, @timezone)}
            </span>
          </span>
          <span class="mentions-row__body mt-1 block break-words">{preview(mention)}</span>
        </button>
      </div>

      <.list_load_more_button
        :if={State.more?(@state)}
        target={@target}
        event="mentions_load_more"
        loading={State.loading?(@state)}
        testid="mentions-load-more"
      />
      <.list_announcer state={@state} />
      <.list_error_retry
        :if={State.error?(@state)}
        target={@target}
        on_retry="mentions_load_more"
        text={dgettext("dialogs", "Could not load more mentions.")}
      />
      <.list_end_marker :if={State.exhausted?(@state)} testid="mentions-end" />
    </div>
    """
  end

  # The stored plain text when there is one — a mention shown with its IRC
  # control bytes intact would print the colour's digits as text.
  @spec preview(map()) :: String.t()
  defp preview(mention) do
    (Map.get(mention, :plain_content) || Map.get(mention, :content) || "")
    |> String.slice(0, 200)
  end

  @spec nick_class(function() | nil, String.t()) :: String.t() | nil
  defp nick_class(nil, _nick), do: nil
  defp nick_class(nick_color_fn, nick), do: nick_color_fn.(nick)

  # The newest mention, drawn where it happened. The island passes the row
  # because a stream cannot be read back out of the component.
  @spec mention_lines(map() | nil) :: [map()]
  defp mention_lines(nil), do: []

  defp mention_lines(row) do
    [
      %{text: Map.get(row, :author_nickname, ""), tone: :muted},
      %{text: row_text(row), tone: :danger}
    ]
  end

  # Both the pin list and the banner read the same field, and a row that
  # carries no plain text still has to draw as something.
  @spec row_text(map()) :: String.t()
  defp row_text(row) do
    (Map.get(row, :plain_content) || Map.get(row, :content) || "")
    |> String.slice(0, 60)
  end
end
