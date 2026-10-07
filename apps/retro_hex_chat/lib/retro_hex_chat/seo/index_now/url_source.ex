defmodule RetroHexChat.SEO.IndexNow.UrlSource do
  @moduledoc """
  Where the URLs IndexNow announces come from.

  The public pages, their addresses and the day each last changed belong to the
  web layer; the job that announces them belongs here. The implementation is
  named in config (`config :retro_hex_chat, :index_now, url_source: …`), so the
  domain reaches it at runtime without compiling against the web app.
  """

  @doc "Absolute URLs of the public pages whose content changed on or after `since`."
  @callback pages_changed_since(since :: Date.t()) :: [String.t()]

  @doc "Absolute URLs of the archive pages that a published channel gained on `day`."
  @callback archive_day(day :: Date.t()) :: [String.t()]
end
