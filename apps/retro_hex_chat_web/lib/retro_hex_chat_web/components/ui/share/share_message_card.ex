defmodule RetroHexChatWeb.Components.UI.ShareMessageCard do
  @moduledoc false
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  attr :card, :map,
    default: nil,
    doc: "a ShareLinks resolution, or nil when the message carries no link of ours"

  attr :subject, :map, default: nil, doc: "%{name, tagline, icon} for what was shared"
  attr :enter_path, :string, default: nil

  @spec share_message_card(map()) :: Phoenix.LiveView.Rendered.t()
  def share_message_card(assigns) do
    ~H"""
    <div
      :if={@card}
      class="shadow-retro-field bg-canvas my-1 flex max-w-md items-center gap-2 p-2"
      data-testid="share-message-card"
      data-share-kind={@card.kind}
    >
      <span class="shrink-0">
        {apply(Icons, icon_name(@subject, @card), [%{class: "h-8 w-8"}])}
      </span>

      <span class="min-w-0 flex-1">
        <span class="block truncate font-bold">{heading(@subject, @card)}</span>
        <span class="text-muted-foreground block truncate text-sm">
          {subtitle(@subject, @card)}
        </span>
      </span>

      <.button navigate={@enter_path} size="sm" class="shrink-0" data-testid="share-message-enter">
        <:icon><Icons.icon_btn_link class="h-4 w-4" /></:icon>
        {dgettext("share", "Join")}
      </.button>
    </div>
    """
  end

  defp icon_name(%{icon: icon}, _card) when is_binary(icon) do
    name = :"icon_#{icon}"
    if function_exported?(Icons, name, 1), do: name, else: :icon_hex_stone
  end

  defp icon_name(_subject, %{kind: "play"}), do: :icon_game_pong
  defp icon_name(_subject, _card), do: :icon_hex_stone

  defp heading(%{name: name}, _card) when is_binary(name), do: name
  defp heading(_subject, %{kind: "play"}), do: dgettext("share", "A game")
  defp heading(_subject, _card), do: dgettext("share", "An invitation")

  # The subtitle says who, not where: a channel name here would show up in a
  # conversation whose readers may not be in that channel.
  defp subtitle(_subject, %{creator_nick: nick}) when is_binary(nick),
    do: dgettext("share", "shared by %{nickname}", nickname: nick)

  defp subtitle(_subject, _card), do: dgettext("share", "shared with this conversation")
end
