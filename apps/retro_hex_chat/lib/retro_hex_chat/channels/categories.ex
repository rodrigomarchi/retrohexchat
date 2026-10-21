defmodule RetroHexChat.Channels.Categories do
  @moduledoc """
  What a channel is about — news, games, sport — drawn as a coloured plaque
  beside its name, so a list of rooms can be read at a glance.

  The set is closed: each category has a plaque drawn for it in the web
  layer, and a test keeps the two lists equal. A channel's founder picks one
  (`/cs category`); a channel nobody gave one draws nothing.
  """

  use Gettext, backend: RetroHexChat.Gettext

  @codes ~w(social news tech dev security ai science games sports money culture life retro help)

  @doc "Every category, in the order a list offers them."
  @spec codes() :: [String.t()]
  def codes, do: @codes

  @doc "Whether `code` is a category."
  @spec valid?(term()) :: boolean()
  def valid?(code), do: code in @codes

  @doc "The category `code` names, however it was cased, or nil."
  @spec normalize(String.t() | nil) :: String.t() | nil
  def normalize(code) when is_binary(code) do
    code = code |> String.trim() |> String.downcase()
    if code in @codes, do: code
  end

  def normalize(_code), do: nil

  @doc "The category's name in the reader's language, or nil for no category."
  @spec label(String.t() | nil) :: String.t() | nil
  def label("social"), do: dgettext("channels", "Social")
  def label("news"), do: dgettext("channels", "News")
  def label("tech"), do: dgettext("channels", "Technology")
  def label("dev"), do: dgettext("channels", "Programming")
  def label("security"), do: dgettext("channels", "Security")
  def label("ai"), do: dgettext("channels", "Artificial intelligence")
  def label("science"), do: dgettext("channels", "Science")
  def label("games"), do: dgettext("channels", "Games")
  def label("sports"), do: dgettext("channels", "Sports")
  def label("money"), do: dgettext("channels", "Economy")
  def label("culture"), do: dgettext("channels", "Culture")
  def label("life"), do: dgettext("channels", "Lifestyle")
  def label("retro"), do: dgettext("channels", "Retro computing")
  def label("help"), do: dgettext("channels", "Help")
  def label(_code), do: nil
end
