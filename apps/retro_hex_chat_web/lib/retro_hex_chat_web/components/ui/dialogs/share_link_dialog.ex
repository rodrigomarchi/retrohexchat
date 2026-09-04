defmodule RetroHexChatWeb.Components.UI.ShareLinkDialog do
  @moduledoc """
  The address a room hands out, and the two things you do with it.

  Minting a link is a gesture of a few seconds whose result you need for a few
  more. Left inline it is a permanent band: on a call surface that band is 46
  pixels of window height that never comes back, holding a field two thirds
  empty, and on a phone the same field collapses to a sliver too narrow to show
  a single character of the address it exists to reveal.

  So the result is a dialog, sized by itself rather than by whatever chrome it
  was wedged into. It is the shape the *receiving* half already has at
  `/join/:slug`, which is the half of this feature that reads as finished.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :url, :string, default: nil
  attr :on_close, :any, required: true
  attr :on_revoke, :any, default: nil
  attr :revoke_target, :any, default: nil

  attr :scope, :atom,
    default: :viewport,
    values: [:viewport, :window],
    doc: "`:window` when the host renders it inside a surface's own desktop window"

  @spec share_link_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def share_link_dialog(assigns) do
    ~H"""
    <span data-testid={@id}>
      <.dialog id={@id} show={@show} scope={@scope} on_cancel={@on_close}>
        <.dialog_header id={@id} title={dgettext("share", "Share link")} on_close={@on_close}>
          <:icon><Icons.icon_btn_link class="h-[16px] w-[16px]" /></:icon>
        </.dialog_header>

        <.dialog_body>
          <p class="text-xs">
            {dgettext("share", "Anyone who opens this link can come in.")}
          </p>

          <%!-- The field is the fallback, so it is given the width to be one:
                an address you can see and select is what still works when the
                clipboard is refused, and it cannot do that truncated. --%>
          <input
            id={"#{@id}-url"}
            type="text"
            readonly
            value={@url}
            class="shadow-retro-field mt-2 w-full px-1 py-[2px] font-mono text-sm"
            data-testid="share-url"
            aria-label={dgettext("share", "Share link")}
          />
        </.dialog_body>

        <.dialog_footer>
          <.button
            :if={@on_revoke}
            type="button"
            variant="ghost"
            phx-click={@on_revoke}
            phx-target={@revoke_target}
            data-confirm={dgettext("share", "Stop this link from working? The room stays open.")}
            data-testid="share-revoke"
            class="mr-auto"
          >
            <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
            {dgettext("share", "Revoke")}
          </.button>

          <.button
            id={"#{@id}-copy"}
            type="button"
            phx-hook="CopyValueHook"
            data-copy-from={"#{@id}-url"}
            data-copied-label={dgettext("share", "Copied!")}
            data-testid="share-copy"
          >
            <:icon><Icons.icon_copy class="h-4 w-4" /></:icon>
            {dgettext("share", "Copy")}
          </.button>

          <.button type="button" variant="outline" phx-click={@on_close} data-testid="share-close">
            <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
            {dgettext("share", "Close")}
          </.button>
        </.dialog_footer>
      </.dialog>
    </span>
    """
  end
end
