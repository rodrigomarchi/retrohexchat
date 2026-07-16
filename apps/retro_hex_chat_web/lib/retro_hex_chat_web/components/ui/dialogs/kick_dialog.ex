defmodule RetroHexChatWeb.Components.UI.KickDialog do
  @moduledoc """
  Kick notification dialog for the showcase design system.

  Composed from dialog + button primitives. Displays a notification when the
  current user has been kicked from a channel, with details about the channel,
  kicker, and reason.

  ## Usage

      <.kick_dialog
        id="kick-notify"
        show={true}
        kick_info={%{channel: "#lobby", kicker: "Admin", reason: "Flooding"}}
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders a kick notification dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :kick_info, :map,
    default: nil,
    doc: "Map with keys :channel, :kicker, :reason"

  attr :on_dismiss, :any, default: nil, doc: "JS command or event name to dismiss"

  @spec kick_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def kick_dialog(assigns) do
    ~H"""
    <span data-testid="kick-dialog">
      <.dialog id={@id} show={@show} on_cancel={@on_dismiss} class="kd-dialog-wrap">
        <.dialog_header
          id={@id}
          title={dgettext("dialogs", "Kicked from Channel")}
          on_close={@on_dismiss}
        >
          <:icon><Icons.icon_dialog_kick class="w-[16px] h-[16px]" /></:icon>
        </.dialog_header>

        <.dialog_body class="kd-dialog-body">
          <div class="kd-message-row">
            <span class="kd-message-icon" aria-hidden="true">
              <Icons.icon_dialog_kick class="w-5 h-5" />
            </span>

            <div class="kd-message-copy">
              <p class="kd-message-title">
                <%= if @kick_info do %>
                  {dgettext("dialogs", "You were kicked from %{channel}.",
                    channel: kick_channel(@kick_info)
                  )}
                <% else %>
                  {dgettext("dialogs", "You were kicked from the channel.")}
                <% end %>
              </p>

              <dl :if={@kick_info} class="kd-details">
                <div :if={kick_operator(@kick_info) != ""} class="kd-detail">
                  <dt>{dgettext("dialogs", "By")}</dt>
                  <dd>{kick_operator(@kick_info)}</dd>
                </div>

                <div :if={kick_reason(@kick_info) != ""} class="kd-detail">
                  <dt>{dgettext("dialogs", "Reason")}</dt>
                  <dd>{kick_reason(@kick_info)}</dd>
                </div>
              </dl>

              <p class="kd-message-note">
                {dgettext("dialogs", "The channel tab was closed. You can rejoin if allowed.")}
              </p>
            </div>
          </div>
        </.dialog_body>

        <.dialog_footer class="kd-dialog-footer">
          <.button
            variant="default"
            phx-click={@on_dismiss || hide_modal(@id)}
            data-testid="kick-dialog-ok"
            class="kd-dialog-action"
          >
            <:icon><Icons.icon_btn_ok class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "OK")}
          </.button>
        </.dialog_footer>
      </.dialog>
    </span>
    """
  end

  defp kick_channel(kick_info),
    do: text_value(kick_info, [:channel], dgettext("dialogs", "the channel"))

  defp kick_operator(kick_info), do: text_value(kick_info, [:operator, :kicker], "")
  defp kick_reason(kick_info), do: text_value(kick_info, [:reason], "")

  defp text_value(kick_info, keys, default) when is_map(kick_info) do
    keys
    |> Enum.find_value(default, fn key ->
      case Map.get(kick_info, key) || Map.get(kick_info, to_string(key)) do
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

  defp text_value(_kick_info, _keys, default), do: default

  defp non_empty_string(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
