defmodule RetroHexChat.Chat.Attachments.TestStorage do
  @moduledoc false

  @behaviour RetroHexChat.Chat.Attachments.Storage

  @impl true
  def put_file(_path, key, opts) do
    {:ok, %{bucket: Keyword.fetch!(opts, :bucket), key: key}}
  end

  @impl true
  def delete_file(_bucket, _key, _opts), do: :ok

  @impl true
  def presigned_put_url(bucket, key, opts) do
    {:ok,
     %{
       url: "http://storage.test/#{bucket}/#{key}",
       headers: [["content-type", Keyword.get(opts, :content_type, "application/octet-stream")]],
       method: "PUT"
     }}
  end

  @impl true
  def presigned_get_url(bucket, key, _opts) do
    {:ok, "http://storage.test/#{bucket}/#{key}"}
  end
end
