defmodule RetroHexChatWeb.Components.InviteDialog do
  @moduledoc """
  Retro-style invite dialog(s) for channel invitations.
  Renders cascading dialogs when multiple invites are pending.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :pending_invites, :list, default: []

  @spec invite_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def invite_dialog(assigns) do
    ~H"""
    <%= for {invite, index} <- Enum.with_index(@pending_invites) do %>
      <div
        class={["invite-overlay", index == 0 && "invite-overlay--backdrop"]}
        data-testid={"invite-dialog-#{invite.channel}"}
        style={"z-index: #{200 + index}; --invite-offset: #{20 * index}px;"}
      >
        <div class="invite-window window">
          <div class="title-bar">
            <Icons.icon_dialog_invite class="title-bar-icon" />
            <div class="title-bar-text">Channel Invitation</div>
            <div class="title-bar-controls">
              <button
                aria-label="Close"
                phx-click="invite_ignore"
                phx-value-channel={invite.channel}
              >
              </button>
            </div>
          </div>
          <div class="window-body dialog-body--p16">
            <p>
              <strong>{invite.inviter}</strong>
              has invited you to join <strong>{invite.channel}</strong>
            </p>
            <div class="dialog-buttons dialog-buttons--center dialog-buttons--gap-8 u-mt-16">
              <button class="btn-icon" phx-click="invite_accept" phx-value-channel={invite.channel}>
                <Icons.icon_btn_join class="btn-icon__svg" /> Join
              </button>
              <button class="btn-icon" phx-click="invite_ignore" phx-value-channel={invite.channel}>
                <Icons.icon_btn_ignore class="btn-icon__svg" /> Ignore
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
