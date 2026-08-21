defmodule RetroHexChat.Scraper.ImageFetcher do
  @moduledoc """
  Behaviour for downloading publisher images before thumbnailing.
  """

  @type fetched_image :: %{
          required(:body) => binary(),
          required(:content_type) => String.t(),
          required(:final_url) => String.t(),
          required(:byte_size) => pos_integer()
        }

  @callback fetch(String.t(), keyword()) :: {:ok, fetched_image()} | {:error, term()}
end
