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
          <:icon><.inline_icon name={mode_icon(@mode)} class="h-[16px] w-[16px]" /></:icon>
        </.dialog_header>

        <.dialog_body>
          <div class="flex items-start gap-2 text-xs">
            <span class={dialog_badge_class(@mode)}>
              <.inline_icon name={mode_icon(@mode)} class="h-5 w-5" />
            </span>
            <div class="min-w-0">
              <p>{body(@mode, @peer, @new_peer)}</p>
              <div class="mt-2 grid gap-1">
                <div
                  :for={impact <- impact_items(@mode)}
                  class="flex min-w-0 items-center gap-1 text-muted-foreground"
                >
                  <.inline_icon name={impact.icon} class="h-3.5 w-3.5 shrink-0" />
                  <span class="truncate">{impact.label}</span>
                </div>
              </div>
            </div>
          </div>
        </.dialog_body>

        <.dialog_footer>
          <.button
            variant="destructive"
            phx-click={@on_confirm}
            data-testid="p2p-confirm-dialog-confirm"
          >
            <:icon><.inline_icon name={confirm_icon(@mode)} class="h-4 w-4" /></:icon>
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

  attr :name, :atom, required: true
  attr :class, :string, default: nil

  defp inline_icon(assigns) do
    ~H"""
    {apply(Icons, @name, [%{class: @class}])}
    """
  end

  defp mode_icon(:end), do: :icon_phone_end
  defp mode_icon(:close), do: :icon_protocol_p2p_compact
  defp mode_icon(:switch), do: :icon_btn_join

  defp confirm_icon(:switch), do: :icon_btn_join
  defp confirm_icon(_mode), do: :icon_btn_disconnect

  defp dialog_badge_class(:switch),
    do: "flex h-9 w-9 shrink-0 items-center justify-center bg-warning shadow-retro-sunken"

  defp dialog_badge_class(_mode),
    do:
      "flex h-9 w-9 shrink-0 items-center justify-center bg-destructive text-destructive-foreground shadow-retro-sunken"

  defp impact_items(:end) do
    [
      %{icon: :icon_camera_off, label: dgettext("dialogs", "Audio/video tracks stop")},
      %{icon: :icon_file_send, label: dgettext("dialogs", "File transfers stop")},
      %{icon: :icon_joystick, label: dgettext("dialogs", "P2P games close")}
    ]
  end

  defp impact_items(:close) do
    [
      %{icon: :icon_phone_end, label: dgettext("dialogs", "The whole P2P session disconnects")},
      %{icon: :icon_win_minimize, label: dgettext("dialogs", "Minimize to keep it running")},
      %{
        icon: :icon_protocol_p2p_compact,
        label: dgettext("dialogs", "Only one P2P session can be active")
      }
    ]
  end

  defp impact_items(:switch) do
    [
      %{icon: :icon_phone_end, label: dgettext("dialogs", "Current P2P session closes first")},
      %{icon: :icon_btn_join, label: dgettext("dialogs", "New invite starts after confirmation")},
      %{icon: :icon_privacy, label: dgettext("dialogs", "Privacy and relay settings carry over")}
    ]
  end
end
