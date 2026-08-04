defmodule RetroHexChat.Chat.Attachments.Storage do
  @moduledoc """
  Storage boundary for chat attachments.
  """

  @type put_opts :: [
          bucket: String.t(),
          content_type: String.t(),
          byte_size: non_neg_integer()
        ]

  @callback put_file(Path.t(), String.t(), put_opts()) :: {:ok, map()} | {:error, term()}
  @callback presigned_put_url(String.t(), String.t(), keyword()) ::
              {:ok, map()} | {:error, term()}
  @callback presigned_get_url(String.t(), String.t(), keyword()) ::
              {:ok, String.t()} | {:error, term()}
end
