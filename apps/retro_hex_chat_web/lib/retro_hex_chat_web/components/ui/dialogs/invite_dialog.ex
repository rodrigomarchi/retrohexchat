defmodule RetroHexChatWeb.Components.UI.InviteDialog do
  @moduledoc """
  Channel invite notification dialog component for the showcase design system.

  Composed from dialog + button primitives.
  Renders stacked dialog cards for each pending invite, each with
  Join and Ignore buttons.

  ## Usage

      <.invite_dialog
        id="invite-dialog"
        show={true}
        invites={[
          %{channel: "#lobby", from: "alice"},
          %{channel: "#dev", from: "bob"}
        ]}
        on_accept="accept_invite"
        on_ignore="ignore_invite"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders a stacked invite notification dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :invites, :list,
    default: [],
    doc: "List of invite maps with :channel and :from keys"

  attr :on_accept, :any, default: nil, doc: "JS command or event name for accepting an invite"
  attr :on_ignore, :any, default: nil, doc: "JS command or event name for ignoring an invite"

  @spec invite_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def invite_dialog(assigns) do
    ~H"""
    <span data-testid="invite-dialog">
      <.dialog id={@id} show={@show}>
        <.dialog_header id={@id} title="Channel Invite">
          <:icon><Icons.icon_dialog_invite class="w-4 h-4" /></:icon>
        </.dialog_header>

        <.dialog_body>
          <div class="space-y-retro-8">
            <p class="text-xs text-muted-foreground">
              You have been invited to join the following channels:
            </p>

            <div class="space-y-retro-4">
              <div
                :for={{invite, index} <- Enum.with_index(@invites)}
                class="shadow-retro-window bg-surface p-[2px]"
                style={"position: relative; z-index: #{10 + index}; margin-top: #{index * 4}px;"}
                data-testid={"invite-card-#{invite.channel}"}
              >
                <div class="bg-gradient-to-r from-primary to-highlight-light px-retro-4 py-[2px]">
                  <span class="text-xs font-bold text-white">{invite.channel}</span>
                </div>
                <div class="p-retro-8">
                  <p class="text-xs mb-retro-8">
                    <span class="font-bold">{invite.from}</span>
                    {" "}has invited you to join{" "}
                    <span class="font-bold">{invite.channel}</span>.
                  </p>
                  <div class="flex gap-retro-4">
                    <.button
                      variant="default"
                      phx-click={@on_accept}
                      phx-value-channel={invite.channel}
                      data-testid={"invite-join-#{invite.channel}"}
                    >
                      <:icon><Icons.icon_dialog_invite class="w-4 h-4" /></:icon>
                      Join
                    </.button>
                    <.button
                      variant="outline"
                      phx-click={@on_ignore}
                      phx-value-channel={invite.channel}
                      data-testid={"invite-ignore-#{invite.channel}"}
                    >
                      <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                      Ignore
                    </.button>
                  </div>
                </div>
              </div>
            </div>

            <p :if={@invites == []} class="text-xs text-muted-foreground italic">
              No pending invites.
            </p>
          </div>
        </.dialog_body>
      </.dialog>
    </span>
    """
  end
end
