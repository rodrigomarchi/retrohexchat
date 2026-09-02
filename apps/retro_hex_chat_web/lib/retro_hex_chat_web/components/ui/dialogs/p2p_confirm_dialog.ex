defmodule RetroHexChatWeb.Components.UI.P2PConfirmDialog do
  @moduledoc """
  Confirmation dialog for destructive P2P session actions.

  Composed from dialog + button primitives. One mode is left, `:end`: confirm
  ending the active session with `peer`.

  There were three. `:close` warned that the X on a session window disconnected
  the whole session, and `:switch` asked whether to end one session to accept
  another — both were properties of the chat's single P2P window. A session
  lives at its own address now: the window there is pinned and has no X, and a
  person can hold a session with several peers at once, so neither question can
  be asked any more.

  ## Usage

      <.p2p_confirm_dialog
        id="p2p-confirm"
        show={true}
        peer="alice"
        on_confirm="p2p_confirm_end"
        on_cancel="p2p_confirm_cancel"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders the P2P end confirmation dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :mode, :atom, default: :end, values: [:end]
  attr :peer, :string, default: nil
  attr :on_confirm, :any, required: true
  attr :on_cancel, :any, required: true

  attr :scope, :atom,
    default: :viewport,
    values: [:viewport, :window],
    doc: "`:window` when the host renders it inside the session's own desktop window"

  @spec p2p_confirm_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def p2p_confirm_dialog(assigns) do
    ~H"""
    <span data-testid={@id}>
      <.dialog id={@id} show={@show} scope={@scope}>
        <.dialog_header id={@id} title={title(@mode)}>
          <:icon><.inline_icon name={mode_icon(@mode)} class="h-[16px] w-[16px]" /></:icon>
        </.dialog_header>

        <.dialog_body>
          <div class="flex items-start gap-2 text-xs">
            <span class={dialog_badge_class(@mode)}>
              <.inline_icon name={mode_icon(@mode)} class="h-5 w-5" />
            </span>
            <div class="min-w-0">
              <p>{body(@mode, @peer)}</p>
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
            data-testid={"#{@id}-confirm"}
          >
            <:icon><.inline_icon name={confirm_icon(@mode)} class="h-4 w-4" /></:icon>
            {confirm_label(@mode)}
          </.button>
          <.button variant="outline" phx-click={@on_cancel} data-testid={"#{@id}-cancel"}>
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Cancel")}
          </.button>
        </.dialog_footer>
      </.dialog>
    </span>
    """
  end

  defp title(:end), do: dgettext("dialogs", "End P2P Session")

  defp body(:end, peer) do
    dgettext(
      "dialogs",
      "End the P2P session with %{peer}? Any call, game or file transfer in progress will stop.",
      peer: peer || "?"
    )
  end

  defp confirm_label(:end), do: dgettext("dialogs", "End session")

  attr :name, :atom, required: true
  attr :class, :string, default: nil

  defp inline_icon(assigns) do
    ~H"""
    {apply(Icons, @name, [%{class: @class}])}
    """
  end

  defp mode_icon(:end), do: :icon_phone_end
  defp confirm_icon(_mode), do: :icon_btn_disconnect

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
end
