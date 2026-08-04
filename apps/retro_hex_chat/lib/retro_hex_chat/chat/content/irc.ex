defmodule RetroHexChat.Chat.Content.Irc do
  @moduledoc false

  alias RetroHexChat.Chat.{Formatter, URLDetector}

  @type safe_html :: {:safe, String.t()}

  @spec render_html(String.t(), keyword()) :: safe_html()
  def render_html(content, opts), do: Formatter.to_safe_html(content, opts)

  @spec plain_text(String.t()) :: String.t()
  def plain_text(content), do: Formatter.visible_text(content)

  @spec extract_urls(String.t()) :: [String.t()]
  def extract_urls(content), do: URLDetector.extract_urls(content)
end
