defmodule RetroHexChatWeb.I18n.Locales do
  @moduledoc """
  Supported locale metadata shared by locale negotiation and layouts: the set
  itself is `RetroHexChat.Locales`; this adds what only a page needs.
  """

  alias RetroHexChat.Locales, as: Supported

  @spec all() :: [map()]
  defdelegate all, to: Supported

  @spec enabled() :: [map()]
  defdelegate enabled, to: Supported

  @spec codes() :: [String.t()]
  defdelegate codes, to: Supported

  @spec find(String.t()) :: map() | nil
  defdelegate find(code), to: Supported

  @spec normalize(String.t() | nil) :: String.t() | nil
  defdelegate normalize(locale), to: Supported

  @spec bcp47(String.t()) :: String.t()
  def bcp47(code) do
    case find(code) do
      %{bcp47: bcp47} -> bcp47
      _missing -> "en"
    end
  end

  @spec direction(String.t()) :: String.t()
  def direction(code) do
    case find(code) do
      %{direction: direction} -> direction
      _missing -> "ltr"
    end
  end

  @spec open_graph(String.t()) :: String.t()
  def open_graph(code) do
    case find(code) do
      %{open_graph: open_graph} -> open_graph
      _missing -> "en_US"
    end
  end
end
