defmodule RetroHexChat.Chat.Content.Plain do
  @moduledoc false

  alias RetroHexChat.Chat.Content.Html
  alias RetroHexChat.Chat.URLDetector

  @type safe_html :: {:safe, String.t()}

  @spec render_html(String.t(), keyword()) :: safe_html()
  def render_html(content, _opts), do: {:safe, Html.escape(content)}

  @spec plain_text(String.t()) :: String.t()
  def plain_text(content), do: content

  @spec extract_urls(String.t()) :: [String.t()]
  def extract_urls(content), do: URLDetector.extract_urls(content)
end
