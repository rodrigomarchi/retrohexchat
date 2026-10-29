defmodule RetroHexChat.Radio.Catalog do
  @moduledoc """
  Where Hex Radio's stations come from.

  Injected (`config :retro_hex_chat, :radio_catalog`) so the window can be
  driven without the internet: production reads Radio Browser
  (`RetroHexChat.Radio.RadioBrowser`), the browser tests a fixed list
  (`RetroHexChat.Radio.Fixture`).
  """

  @typedoc """
  What to list: the most played stations, a genre's, the stations whose name
  matches a text, or the stations with these ids (the favourites).
  """
  @type query :: :top | {:tag, String.t()} | {:name, String.t()} | {:ids, [String.t()]}

  @doc "Raw station records, as Radio Browser describes them, for `query`."
  @callback records(query(), limit :: pos_integer()) :: {:ok, [map()]} | {:error, term()}

  @doc "Tells the catalog a station was played, so its popularity counts it."
  @callback played(id :: String.t()) :: :ok
end
