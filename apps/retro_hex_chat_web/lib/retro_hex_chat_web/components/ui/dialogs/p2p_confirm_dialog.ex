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

  import RetroHexChatWeb.Components.UI.ConfirmDialog

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
    <.confirm_dialog
      id={@id}
      show={@show}
      scope={@scope}
      title={title(@mode)}
      message={body(@mode, @peer)}
      icon={mode_icon(@mode)}
      tone={mode_tone(@mode)}
      impacts={impact_items(@mode)}
      variant="destructive"
      confirm_label={confirm_label(@mode)}
      confirm_icon={confirm_icon(@mode)}
      on_confirm={@on_confirm}
      on_cancel={@on_cancel}
    />
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

  defp mode_icon(:end), do: :icon_phone_end
  defp confirm_icon(_mode), do: :icon_btn_disconnect

  # Ending a call is destructive and there is no other mode here.
  defp mode_tone(_mode), do: :danger

  defp impact_items(:end) do
    [
      %{icon: :icon_camera_off, label: dgettext("dialogs", "Audio/video tracks stop")},
      %{icon: :icon_file_send, label: dgettext("dialogs", "File transfers stop")},
      %{icon: :icon_joystick, label: dgettext("dialogs", "P2P games close")}
    ]
  end
end
