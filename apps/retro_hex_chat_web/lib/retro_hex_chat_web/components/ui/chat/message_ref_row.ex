defmodule RetroHexChatWeb.Components.UI.MessageRefRow do
  @moduledoc """
  A row that points at a message said somewhere else: a mention, a pin, a line
  kept in Saved.

  Each one is the same thing — who said it, where, when, and what — and opening
  it goes to the line in its conversation, so the head and the text are one
  button: everything here that goes somewhere when clicked is something the
  keyboard can reach. What a window adds to the row (who pinned it, a note, an
  Unpin or Remove beside it) goes in the `footer` and `action` slots, so the
  part every list shares is drawn once.

  ## Usage

      <.message_ref_row
        id={dom_id}
        testid={"pinned-row-\#{pin.message_id}"}
        author={pin.author_nickname}
        author_locale={pin.author_locale}
        at={pin.inserted_at}
        timezone={@timezone}
        text={MessageRefRow.preview(pin)}
        phx-click="pinned_open"
        phx-value-message_id={pin.message_id}
      >
        <:footer>pinned by ana</:footer>
        <:action><.button>Unpin</.button></:action>
      </.message_ref_row>
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.NickFlag

  alias RetroHexChatWeb.App.ChatHelpers

  @doc "Renders a row pointing at a message, whose head and text open it."
  attr :id, :string, required: true
  attr :testid, :string, required: true, doc: "the row's test id"
  attr :open_testid, :string, default: nil, doc: "the open button's test id"
  attr :author, :string, required: true
  attr :author_locale, :string, default: nil, doc: "draws the author's flag"
  attr :nick_color_fn, :any, default: nil
  attr :where, :string, default: nil, doc: "the conversation it was said in"
  attr :at, :any, required: true, doc: "when it was said"
  attr :timezone, :string, default: "Etc/UTC"
  attr :text, :string, required: true, doc: "the line, as plain text"
  attr :deleted, :boolean, default: false, doc: "the line is gone; says so instead"
  attr :deleted_testid, :string, default: nil
  attr :rest, :global, doc: "the open button's click and values"

  slot :footer, doc: "what this window adds under the line"
  slot :action, doc: "the button beside the row"

  @spec message_ref_row(map()) :: Phoenix.LiveView.Rendered.t()
  def message_ref_row(assigns) do
    ~H"""
    <div id={@id} class="message-ref-row" data-testid={@testid}>
      <div class="message-ref-row__main">
        <button type="button" class="message-ref-row__open" data-testid={@open_testid} {@rest}>
          <span class="message-ref-row__head">
            <.nick_flag locale={@author_locale} />
            <%!-- The nick names the line, so it keeps its width and the
                  conversation beside it is what gives way. --%>
            <span class={[
              "max-w-[60%] shrink-0 truncate font-bold",
              @nick_color_fn && @nick_color_fn.(@author)
            ]}>
              {@author}
            </span>
            <span :if={@where} class="min-w-0 truncate text-muted-foreground">{@where}</span>
            <span class="ml-auto shrink-0 text-muted-foreground">
              {ChatHelpers.format_datetime(@at, @timezone)}
            </span>
          </span>
          <span
            :if={@deleted}
            class="message-ref-row__body italic text-muted-foreground"
            data-testid={@deleted_testid}
          >
            {dgettext("dialogs", "This message was deleted.")}
          </span>
          <span :if={!@deleted} class="message-ref-row__body break-words">{@text}</span>
        </button>
        <div :if={@footer != []} class="message-ref-row__footer">{render_slot(@footer)}</div>
      </div>
      {render_slot(@action)}
    </div>
    """
  end

  @doc """
  The line a row shows: the stored plain text when there is one, cut to
  `limit`. A line shown with its IRC control bytes intact would print the
  colour's digits as text, and a row with no text still draws as something.
  """
  @spec preview(map(), pos_integer()) :: String.t()
  def preview(row, limit \\ 200) do
    (Map.get(row, :plain_content) || Map.get(row, :content) || "")
    |> String.slice(0, limit)
  end
end
