defmodule RetroHexChat.Chat.Attachments.S3Storage do
  @moduledoc """
  S3-compatible implementation for chat attachment object storage.
  """

  @behaviour RetroHexChat.Chat.Attachments.Storage

  @impl true
  def put_file(path, key, opts) do
    bucket = Keyword.fetch!(opts, :bucket)
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")

    with {:ok, body} <- File.read(path),
         {:ok, _result} <-
           bucket
           |> ExAws.S3.put_object(key, body, content_type: content_type)
           |> ExAws.request() do
      {:ok, %{bucket: bucket, key: key}}
    end
  end

  @impl true
  def presigned_put_url(bucket, key, opts) do
    expires_in = Keyword.get(opts, :expires_in, 300)
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")
    headers = [{"content-type", content_type}]

    ExAws.S3.presigned_url(ExAws.Config.new(:s3), :put, bucket, key,
      expires_in: expires_in,
      headers: headers
    )
    |> case do
      {:ok, url} -> {:ok, %{url: url, headers: encode_headers(headers), method: "PUT"}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def presigned_get_url(bucket, key, opts) do
    expires_in = Keyword.get(opts, :expires_in, 300)

    ExAws.S3.presigned_url(ExAws.Config.new(:s3), :get, bucket, key, expires_in: expires_in)
  end

  defp encode_headers(headers) do
    Enum.map(headers, fn {key, value} -> [key, value] end)
  end
end
