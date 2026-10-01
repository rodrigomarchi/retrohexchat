defmodule RetroHexChatWeb.Components.UI.ThreadDialog do
  @moduledoc """
  The window that shows one disagreement from beginning to end.

  The line that started it sits at the top, and under it everything that
  answered it, oldest first — a conversation is read forwards, and the replies
  are still where they were written in the room above. Nothing is moved here;
  this only puts the scattered half of a conversation next to itself.

  Every line is drawn by `MessageRow`, the same component the conversation uses.
  A window that drew its own idea of a message would drift from the real one the
  first time a message gained a field, and it would also be the second place
  that has to know how IRC control bytes are printed.

  A message can therefore be on screen twice — once in the room, once here —
  so a `data-testid` inside this panel is not unique in the document. Scope to
  `[data-testid="thread-lines"]` rather than reaching for a row by id alone.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.ListStates
  import RetroHexChatWeb.Components.UI.MessageRow
  import RetroHexChatWeb.Components.UI.DialogBanner

  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PaginatedList.State

  @doc "Renders the Thread window body."
  attr :id, :string, required: true
  attr :root, :map, default: nil, doc: "the message the thread hangs off"
  attr :replies, :any, required: true, doc: "the stream of reply rows"
  attr :state, :any, default: nil, doc: "PaginatedList.State for the list"
  attr :target, :any, default: nil
  attr :nick_color_fn, :any, required: true
  attr :timestamp_format, :atom, default: :time
  attr :timezone, :string, default: "Etc/UTC"
  attr :strip_formatting, :boolean, default: false
  attr :viewer, :string, default: nil

  @spec thread_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def thread_panel(assigns) do
    ~H"""
    <div id={"#{@id}-panel"} class="flex h-full min-h-0 flex-col gap-retro-4">
      <.dialog_banner heading={dgettext("dialogs", "One disagreement, start to finish")}>
        <:art>
          <Diagrams.diagram_dialog_preview
            kind={:query}
            title={dgettext("dialogs", "Channel")}
            lines={thread_lines(@root)}
            label={
              dgettext("dialogs", "A miniature of the line a thread hangs off and its first answer")
            }
          />
        </:art>
        <:glyph><Icons.icon_chat class="h-8 w-8" /></:glyph>
        {dgettext(
          "dialogs",
          "A thread keeps an argument out of the room it started in: the replies live here instead of scrolling the channel. Everyone in the channel can open it and read the whole thing."
        )}
      </.dialog_banner>

      <.list_empty_state
        :if={is_nil(@root)}
        icon={:chat}
        title={dgettext("dialogs", "No thread is open.")}
        text={
          dgettext(
            "dialogs",
            "A message that somebody answered shows how many replies it collected. Choose that to read them together."
          )
        }
      />

      <div
        :if={@root}
        class="shrink-0 border-b-2 border-border bg-white p-2 shadow-retro-field"
        data-testid="thread-root"
      >
        <.message_row_body
          msg={@root}
          nick_color_fn={@nick_color_fn}
          timestamp_format={@timestamp_format}
          timezone={@timezone}
          strip_formatting={@strip_formatting}
          viewer={@viewer}
        />
      </div>

      <.list_empty_state
        :if={@root && State.empty?(@state)}
        icon={:chat}
        title={dgettext("dialogs", "Nobody has answered this yet.")}
        text={dgettext("dialogs", "Your reply starts the thread, and stays in the room as well.")}
      />

      <div
        :if={@root && not State.empty?(@state)}
        id={"#{@id}-list"}
        class="min-h-[160px] flex-1 overflow-y-auto bg-white p-1 shadow-retro-field retro-scrollbar"
        phx-hook="InfiniteScrollHook"
        phx-update="stream"
        data-edge="bottom"
        data-target={@target}
        data-event="thread_load_more"
        data-has-more={to_string(State.more?(@state))}
        data-loading={to_string(State.loading?(@state))}
        data-testid="thread-lines"
      >
        <div
          :for={{dom_id, reply} <- @replies}
          id={dom_id}
          class="border-b border-border p-2 last:border-b-0"
          data-testid={"thread-reply-#{reply.id}"}
        >
          <.message_row_body
            msg={reply}
            nick_color_fn={@nick_color_fn}
            timestamp_format={@timestamp_format}
            timezone={@timezone}
            strip_formatting={@strip_formatting}
            viewer={@viewer}
          />
        </div>
      </div>

      <.list_load_more_button
        :if={State.more?(@state)}
        target={@target}
        event="thread_load_more"
        loading={State.loading?(@state)}
        testid="thread-load-more"
      />
      <.list_announcer state={@state} />
      <.list_error_retry
        :if={State.error?(@state)}
        target={@target}
        on_retry="thread_load_more"
        text={dgettext("dialogs", "Could not load more of this thread.")}
      />
      <.list_end_marker :if={State.exhausted?(@state)} testid="thread-end" />

      <%!-- Writing happens in the room's own composer: the reply belongs to the
            conversation, and a second input here would be a second place to
            look for what you just typed. This only aims that composer. --%>
      <.button
        :if={@root}
        type="button"
        variant="outline"
        class="shrink-0"
        phx-click="thread_reply"
        phx-target={@target}
        data-testid="thread-reply"
      >
        <:icon><Icons.icon_chat class="h-4 w-4" /></:icon>
        {dgettext("dialogs", "Reply in this thread")}
      </.button>
    </div>
    """
  end

  # The line everything else hangs off, which is the one thing the reply list
  # below cannot show on its own.
  @spec thread_lines(map() | nil) :: [map()]
  defp thread_lines(nil), do: []

  defp thread_lines(root) do
    [
      %{text: Map.get(root, :author) || "", tone: :muted},
      %{text: root_text(root), tone: :accent}
    ]
  end

  @spec root_text(map()) :: String.t()
  defp root_text(root) do
    (Map.get(root, :plain_content) || Map.get(root, :content) || "")
    |> String.slice(0, 60)
  end
end
