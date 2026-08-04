defmodule RetroHexChat.Bots.Capabilities.RSS.UrlGuard do
  @moduledoc """
  Compatibility facade for RSS feed URL checks.

  Server-side URL fetch safety is shared by RSS, link previews, and future chat
  cards. New code should call `RetroHexChat.Net.URLGuard` directly.
  """

  alias RetroHexChat.Net.URLGuard

  @type verdict :: URLGuard.verdict()

  @spec check(String.t()) :: verdict()
  defdelegate check(url), to: URLGuard

  @spec private?(:inet.ip_address()) :: boolean()
  defdelegate private?(address), to: URLGuard
end
