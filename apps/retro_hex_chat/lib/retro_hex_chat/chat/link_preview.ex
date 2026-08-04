defmodule RetroHexChat.Chat.LinkPreview do
  @moduledoc """
  Behaviour for fetching lightweight page preview metadata from URLs.
  """

  @type metadata :: %{
          optional(:title) => String.t() | nil,
          optional(:description) => String.t() | nil,
          optional(:image) => String.t() | nil,
          optional(:url) => String.t() | nil,
          optional(:site_name) => String.t() | nil
        }

  @callback fetch_title(String.t()) :: {:ok, String.t()} | {:error, atom()}
  @callback fetch_metadata(String.t()) :: {:ok, metadata()} | {:error, atom()}

  @doc "The link preview implementation in force. Configure `:link_preview_fetcher` to substitute one."
  @spec impl() :: module()
  def impl do
    Application.get_env(
      :retro_hex_chat,
      :link_preview_fetcher,
      RetroHexChat.Chat.LinkPreview.HTTP
    )
  end
end
