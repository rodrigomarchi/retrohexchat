defmodule RetroHexChatWeb.Components.UI.DialogMessage do
  @moduledoc """
  The Win98 message box: a 32×32 glyph in a sunken well, the question beside
  it, and under that what will happen if the reader says yes.

  This is the other half of the dialog grammar. A window that explains itself
  gets `DialogBanner`; a window that interrupts to ask one thing gets this.
  A banner would be wrong here — it puts an illustration between the question
  and the buttons, and delays an answer the reader already has in mind.

  The glyph is the subject, not a warning triangle. Deleting a message draws
  the delete icon and disconnecting draws the plug, because a reader who
  recognises the picture has read the question before reading it. The triangle
  is for the cases that really are warnings.

  The `note` is the part that was missing from most of these: a question
  without its consequence makes the reader guess, and the guess is usually
  "this is reversible".

  `boxed` is the second shape: a form that acts on one subject states it in a
  framed card at the top — who is being muted, what the nickname is changing
  to — rather than asking anything. Mute Duration and Change Nickname had each
  written that card out, with identical rules under different names.
  """
  use RetroHexChatWeb.Component

  @doc "Renders the glyph, the question and what follows from it."
  attr :class, :any, default: nil

  attr :boxed, :boolean,
    default: false,
    doc: "Frame it as a card: the subject of a form, rather than a question"

  attr :label, :string, default: nil, doc: "What the line beneath it is, for a boxed card"

  attr :tone, :atom,
    default: :normal,
    values: [:normal, :warn, :danger],
    doc: "Tints the glyph well. The call dialogs carried this on a badge of their own."

  attr :rest, :global

  slot :glyph, required: true, doc: "The 32×32 icon for the subject of the question"
  slot :inner_block, required: true, doc: "The question, in one sentence"
  slot :note, doc: "What happens if the reader goes ahead; may carry a block"

  @spec dialog_message(map()) :: Phoenix.LiveView.Rendered.t()
  def dialog_message(assigns) do
    ~H"""
    <div
      class={
        classes([
          "dlg-message",
          @boxed && "dlg-message--boxed",
          @tone != :normal && "dlg-message--#{@tone}",
          @class
        ])
      }
      data-dialog-message
      {@rest}
    >
      <span class="dlg-message__glyph" aria-hidden="true">{render_slot(@glyph)}</span>

      <div class="dlg-message__copy">
        <p :if={@label} class="dlg-message__label">{@label}</p>
        <p class={["dlg-message__text", @boxed && "dlg-message__text--value"]}>
          {render_slot(@inner_block)}
        </p>
        <div :if={@note != []} class="dlg-message__note">{render_slot(@note)}</div>
      </div>
    </div>
    """
  end
end
