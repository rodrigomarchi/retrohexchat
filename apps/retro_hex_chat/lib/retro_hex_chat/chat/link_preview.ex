defmodule RetroHexChat.Chat.LinkPreview do
  @moduledoc """
  Behaviour for fetching page titles from URLs.
  """

  @callback fetch_title(String.t()) :: {:ok, String.t()} | {:error, atom()}
end
