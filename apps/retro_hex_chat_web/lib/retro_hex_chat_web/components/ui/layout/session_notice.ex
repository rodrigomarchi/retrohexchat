defmodule RetroHexChatWeb.Components.UI.SessionNotice do
  @moduledoc """
  What a call's or a P2P session's page says when there is no session to
  show: it was refused at the door, it ended, or it moved to another window.

  The page is the window, so the notice is the only thing in it: a message
  box (`DialogMessage`) in the middle of the window, the session's picture
  beside the sentence, and under it what follows — the detail, or the one
  button that gets the session back. Every such state draws this, so a call
  and a P2P session say "this is over" the same way.

  ## Usage

      <.session_notice icon={:icon_protocol_p2p_compact} testid="p2p-left">
        Session ended.
      </.session_notice>
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.DialogMessage

  alias RetroHexChatWeb.Icons

  @doc "Renders the notice in the middle of the session's window."
  attr :icon, :atom, required: true, doc: "an `RetroHexChatWeb.Icons` function, for the session"
  attr :testid, :string, required: true
  attr :rest, :global

  slot :inner_block, required: true, doc: "What happened, in one sentence"
  slot :note, doc: "What follows from it: a detail, or the button that undoes it"

  @spec session_notice(map()) :: Phoenix.LiveView.Rendered.t()
  def session_notice(assigns) do
    ~H"""
    <div class="m-auto w-full max-w-[520px] p-3" data-testid={@testid} {@rest}>
      <.dialog_message>
        <:glyph>{apply(Icons, @icon, [%{class: "h-6 w-6"}])}</:glyph>
        {render_slot(@inner_block)}
        <:note :if={@note != []}>{render_slot(@note)}</:note>
      </.dialog_message>
    </div>
    """
  end
end
