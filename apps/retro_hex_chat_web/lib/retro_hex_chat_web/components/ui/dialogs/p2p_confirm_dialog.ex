defmodule RetroHexChatWeb.Components.UI.P2PConfirmDialog do
  @moduledoc """
  Confirmation dialog for destructive P2P session actions.

  Composed from dialog + button primitives. Three modes:

    * `:end` — confirm ending the active session with `peer`.
    * `:close` — the user clicked X on a session window: closing means
      disconnecting the whole P2P session, so warn before it happens.
    * `:switch` — confirm ending the session with `peer` to accept a new
      invite from `new_peer` (the one-session-at-a-time switch).

  ## Usage

      <.p2p_confirm_dialog
        id="p2p-confirm"
        show={true}
        mode={:switch}
        peer="alice"
        new_peer="bob"
        on_confirm="p2p_confirm_switch"
        on_cancel="p2p_confirm_cancel"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders the P2P end/switch confirmation dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :mode, :atom, default: :end, values: [:end, :close, :switch]
  attr :peer, :string, default: nil
  attr :new_peer, :string, default: nil
  attr :on_confirm, :any, required: true
  attr :on_cancel, :any, required: true

  @spec p2p_confirm_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def p2p_confirm_dialog(assigns) do
    ~H"""
    <span data-testid="p2p-confirm-dialog">
      <.dialog id={@id} show={@show}>
        <.dialog_header id={@id} title={title(@mode)}>
          <:icon><Icons.icon_p2p class="w-[16px] h-[16px]" /></:icon>
        </.dialog_header>

        <.dialog_body>
          <p class="text-xs">{body(@mode, @peer, @new_peer)}</p>
        </.dialog_body>

        <.dialog_footer>
          <.button
            variant="destructive"
            phx-click={@on_confirm}
            data-testid="p2p-confirm-dialog-confirm"
          >
            <:icon><Icons.icon_btn_disconnect class="w-4 h-4" /></:icon>
            {confirm_label(@mode)}
          </.button>
          <.button variant="outline" phx-click={@on_cancel} data-testid="p2p-confirm-dialog-cancel">
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Cancel")}
          </.button>
        </.dialog_footer>
      </.dialog>
    </span>
    """
  end

  defp title(:end), do: dgettext("dialogs", "End P2P Session")
  defp title(:close), do: dgettext("dialogs", "Close P2P Session?")
  defp title(:switch), do: dgettext("dialogs", "Switch P2P Session")

  defp body(:end, peer, _new_peer) do
    dgettext(
      "dialogs",
      "End the P2P session with %{peer}? Any call, game or file transfer in progress will stop.",
      peer: peer || "?"
    )
  end

  defp body(:close, peer, _new_peer) do
    dgettext(
      "dialogs",
      "Closing this window disconnects the whole P2P session with %{peer} — any call, game " <>
        "or file transfer in progress will stop. To keep the session and just tidy up, " <>
        "minimize the window instead.",
      peer: peer || "?"
    )
  end

  defp body(:switch, peer, new_peer) do
    dgettext(
      "dialogs",
      "End the current P2P session with %{peer} and start one with %{new_peer}? Any call, game or file transfer in progress will stop.",
      peer: peer || "?",
      new_peer: new_peer || "?"
    )
  end

  defp confirm_label(:end), do: dgettext("dialogs", "End session")
  defp confirm_label(:close), do: dgettext("dialogs", "Disconnect")
  defp confirm_label(:switch), do: dgettext("dialogs", "Switch")
end
