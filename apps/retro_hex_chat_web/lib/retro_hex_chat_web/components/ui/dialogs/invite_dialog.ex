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
          %{channel: "#lobby", inviter: "alice"},
          %{channel: "#dev", inviter: "bob"}
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
    doc: "List of invite maps with :channel and :inviter keys"

  attr :on_accept, :any, default: nil, doc: "JS command or event name for accepting an invite"
  attr :on_ignore, :any, default: nil, doc: "JS command or event name for ignoring an invite"

  attr :on_dismiss, :any,
    default: nil,
    doc: "JS command or event name for dismissing the top invite"

  @spec invite_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def invite_dialog(assigns) do
    ~H"""
    <span data-testid="invite-dialog">
      <.dialog id={@id} show={@show} on_cancel={@on_dismiss} class="iv-dialog-wrap">
        <.dialog_header
          id={@id}
          title={dgettext("dialogs", "Channel Invite")}
          on_close={@on_dismiss}
        >
          <:icon><Icons.icon_dialog_invite class="w-4 h-4" /></:icon>
        </.dialog_header>

        <.dialog_body class="iv-dialog-body">
          <div class="iv-dialog-stack">
            <p class="iv-summary">
              {dgettext("dialogs", "You have been invited to join the following channels:")}
            </p>

            <div :if={@invites != []} class="iv-invite-list">
              <div
                :for={{invite, index} <- Enum.with_index(@invites)}
                class="iv-invite-item"
                data-testid={"invite-card-#{invite_channel(invite)}"}
                style={"--invite-card-index: #{index};"}
              >
                <div class="iv-invite-main">
                  <span class="iv-invite-icon" aria-hidden="true">
                    <Icons.icon_dialog_invite class="w-4 h-4" />
                  </span>
                  <div class="iv-invite-copy">
                    <p class="iv-invite-channel">{invite_channel(invite)}</p>
                    <p class="iv-invite-meta">
                      {dgettext("dialogs", "Invited by %{inviter}", inviter: invite_inviter(invite))}
                    </p>
                  </div>
                </div>

                <div class="iv-invite-actions">
                  <.button
                    variant="default"
                    phx-click={@on_accept}
                    phx-value-channel={invite_channel(invite)}
                    data-testid={"invite-join-#{invite_channel(invite)}"}
                    class="iv-action-button"
                  >
                    <:icon><Icons.icon_dialog_invite class="w-4 h-4" /></:icon>
                    {dgettext("dialogs", "Join")}
                  </.button>
                  <.button
                    variant="outline"
                    phx-click={@on_ignore}
                    phx-value-channel={invite_channel(invite)}
                    data-testid={"invite-ignore-#{invite_channel(invite)}"}
                    class="iv-action-button"
                  >
                    <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                    {dgettext("dialogs", "Ignore")}
                  </.button>
                </div>
              </div>
            </div>

            <div :if={@invites == []} class="iv-empty-state">
              <span class="iv-invite-icon" aria-hidden="true">
                <Icons.icon_dialog_invite class="w-4 h-4" />
              </span>
              <p>{dgettext("dialogs", "No pending invites.")}</p>
            </div>
          </div>
        </.dialog_body>
      </.dialog>
    </span>
    """
  end

  defp invite_channel(invite), do: text_value(invite, [:channel], dgettext("dialogs", "unknown"))

  defp invite_inviter(invite),
    do: text_value(invite, [:inviter, :from], dgettext("dialogs", "Someone"))

  defp text_value(invite, keys, default) when is_map(invite) do
    keys
    |> Enum.find_value(default, fn key ->
      case Map.get(invite, key) || Map.get(invite, to_string(key)) do
        value when is_binary(value) -> non_empty_string(value)
        value when is_atom(value) -> Atom.to_string(value)
        value when is_integer(value) -> Integer.to_string(value)
        _ -> nil
      end
    end)
    |> case do
      "" -> default
      value -> value
    end
  end

  defp text_value(_invite, _keys, default), do: default

  defp non_empty_string(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
