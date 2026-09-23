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
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.ListStates

  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PaginatedList.State

  @doc "Renders the Pinned window body."
  attr :id, :string, required: true
  attr :pins, :any, required: true, doc: "The stream of pinned rows"
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
        class="min-h-[200px] flex-1 overflow-y-auto bg-white p-1 shadow-retro-field retro-scrollbar"
        phx-hook="InfiniteScrollHook"
        phx-update="stream"
        data-edge="bottom"
        data-target={@target}
        data-event="pinned_load_more"
        data-has-more={to_string(State.more?(@state))}
        data-loading={to_string(State.loading?(@state))}
      >
        <div
          :for={{dom_id, pin} <- @pins}
          id={dom_id}
          class="mentions-row flex w-full items-start gap-retro-4 border-b border-border p-2 last:border-b-0"
          data-testid={"pinned-row-#{pin.message_id}"}
        >
          <button
            type="button"
            class="flex-1 text-left"
            phx-click={@on_open}
            phx-target={@target}
            phx-value-message_id={pin.message_id}
            data-testid={"pinned-open-#{pin.message_id}"}
          >
            <span class="mentions-row__head flex items-center gap-retro-4">
              <span class={["truncate font-bold", nick_class(@nick_color_fn, pin.author_nickname)]}>
                {pin.author_nickname}
              </span>
              <span class="ml-auto shrink-0 text-muted-foreground">
                {ChatHelpers.format_datetime(pin.inserted_at, @timezone)}
              </span>
            </span>
            <span class="mentions-row__body mt-1 block break-words">{preview(pin)}</span>
            <span class="mt-1 block text-muted-foreground">
              {dgettext("dialogs", "pinned by %{nickname}", nickname: pin.pinned_by)}
            </span>
          </button>

          <.button
            :if={@can_unpin}
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
        </div>
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

  # The stored plain text when there is one — a line shown with its IRC control
  # bytes intact would print the colour's digits as text.
  @spec preview(map()) :: String.t()
  defp preview(pin) do
    (Map.get(pin, :plain_content) || Map.get(pin, :content) || "")
    |> String.slice(0, 200)
  end

  @spec nick_class(function() | nil, String.t()) :: String.t() | nil
  defp nick_class(nil, _nick), do: nil
  defp nick_class(nick_color_fn, nick), do: nick_color_fn.(nick)
end
