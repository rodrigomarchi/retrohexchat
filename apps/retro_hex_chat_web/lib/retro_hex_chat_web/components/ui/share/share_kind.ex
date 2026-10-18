defmodule RetroHexChatWeb.Components.UI.ShareKind do
  @moduledoc """
  The picture of a shared link: one per kind of room, or the shared thing's own
  icon when it has one — a game is drawn as that game.

  Both places that draw a shared link ask here — the card in the conversation
  and the invitation window a stranger opens — so the same link is never drawn
  as two different things.
  """

  alias RetroHexChatWeb.Icons

  @doc "The icon function for a kind of link."
  @spec icon(String.t() | nil) :: atom()
  def icon("play"), do: :icon_game_pong
  def icon("call"), do: :icon_protocol_conference_compact
  def icon("space"), do: :icon_community
  def icon("channel"), do: :icon_channels
  def icon("p2p"), do: :icon_protocol_p2p_compact
  def icon(_kind), do: :icon_hex_stone

  @doc """
  The icon for what was shared: the subject's own (`%{icon: "game_doom"}` names
  `Icons.icon_game_doom/1`) when it has one that exists, otherwise the kind's.
  """
  @spec subject_icon(map() | nil, String.t() | nil) :: atom()
  def subject_icon(%{icon: icon}, kind) when is_binary(icon) do
    name = :"icon_#{icon}"
    if function_exported?(Icons, name, 1), do: name, else: icon(kind)
  end

  def subject_icon(_subject, kind), do: icon(kind)
end
