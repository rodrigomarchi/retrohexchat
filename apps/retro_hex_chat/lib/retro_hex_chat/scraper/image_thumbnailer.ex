defmodule RetroHexChat.Scraper.ImageThumbnailer do
  @moduledoc """
  Behaviour for turning a downloaded image into the chat thumbnail format.
  """

  @type thumbnail :: %{
          required(:body) => binary(),
          required(:content_type) => String.t(),
          required(:extension) => String.t(),
          required(:width) => pos_integer(),
          required(:height) => pos_integer(),
          required(:byte_size) => pos_integer()
        }

  @callback thumbnail(binary(), keyword()) :: {:ok, thumbnail()} | {:error, term()}
end
