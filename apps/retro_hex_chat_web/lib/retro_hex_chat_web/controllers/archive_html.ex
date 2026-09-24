defmodule RetroHexChatWeb.ArchiveHTML do
  @moduledoc """
  The two archive pages: a channel's days, and one day's lines.

  Composed from the same window and button primitives every other public page
  uses, so the archive looks like the product rather than like a database
  dump — somebody who arrives here from a search engine is meeting the app for
  the first time, and the page is the whole first impression.
  """
  use RetroHexChatWeb, :html

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Landing.LandingShell

  alias RetroHexChatWeb.Icons

  embed_templates "archive_html/*"

  @doc "The day a reader is most likely to want: the newest one."
  @spec newest_day([String.t()]) :: String.t() | nil
  def newest_day([day | _rest]), do: day
  def newest_day(_days), do: nil

  @doc "`14:03` in UTC — the archive has no reader whose zone it could know."
  @spec at(DateTime.t()) :: String.t()
  def at(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_time()
    |> Calendar.strftime("%H:%M")
  end
end
