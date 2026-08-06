defmodule RetroHexChat.Jobs.AttachmentOrphanCleanupWorkerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.{Attachments, UploadedFile}
  alias RetroHexChat.Jobs.AttachmentOrphanCleanupWorker

  defmodule FailingDeleteStorage do
    @behaviour RetroHexChat.Chat.Attachments.Storage

    @impl true
    def put_file(_path, key, opts) do
      {:ok, %{bucket: Keyword.fetch!(opts, :bucket), key: key}}
    end

    @impl true
    def delete_file(_bucket, _key, _opts), do: {:error, :delete_failed}

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

  setup do
    previous = Application.fetch_env!(:retro_hex_chat, :chat_uploads)

    on_exit(fn ->
      Application.put_env(:retro_hex_chat, :chat_uploads, previous)
    end)

    :ok
  end

  test "cleans old orphan uploads and emits telemetry" do
    file = old_reserved_upload!("WorkerClean", byte_size: 24)
    attach_telemetry()

    assert {:ok, summary} =
             AttachmentOrphanCleanupWorker.perform(%Oban.Job{
               args: %{"limit" => 10, "orphan_age_seconds" => 3_600}
             })

    assert summary.candidates == 1
    assert summary.deleted == 1
    assert summary.bytes_deleted == 24
    assert Repo.get(UploadedFile, file.id).status == "deleted"

    assert_receive {:telemetry_event, [:retro_hex_chat, :attachments, :orphan_cleanup, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "attachments"
    assert metadata.operation == "orphan_cleanup"
    assert metadata.result == "ok"
    assert metadata.candidates == 1
    assert metadata.deleted == 1
    assert metadata.bytes_deleted == 24
  end

  test "returns error for retry when storage delete fails and leaves row eligible" do
    previous = Application.fetch_env!(:retro_hex_chat, :chat_uploads)

    Application.put_env(
      :retro_hex_chat,
      :chat_uploads,
      Keyword.put(previous, :storage, FailingDeleteStorage)
    )

    file = old_reserved_upload!("WorkerFail", byte_size: 24)

    assert {:error, :delete_failed} =
             AttachmentOrphanCleanupWorker.perform(%Oban.Job{
               args: %{"limit" => 10, "orphan_age_seconds" => 3_600}
             })

    assert Repo.get(UploadedFile, file.id).status == "reserved"
    assert Attachments.orphan_upload_count(orphan_age_seconds: 3_600) == 1
  end

  defp old_reserved_upload!(owner, opts) do
    byte_size = Keyword.fetch!(opts, :byte_size)

    assert {:ok, file, _meta} =
             Attachments.prepare_direct_upload(owner, %{
               filename: "orphan.txt",
               content_type: "text/plain",
               byte_size: byte_size
             })

    old = DateTime.utc_now() |> DateTime.add(-7_200, :second)

    from(uploaded_file in UploadedFile, where: uploaded_file.id == ^file.id)
    |> Repo.update_all(set: [inserted_at: old, updated_at: old])

    Repo.get!(UploadedFile, file.id)
  end

  defp attach_telemetry do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      handler_id,
      [
        [:retro_hex_chat, :attachments, :orphan_cleanup, :stop],
        [:retro_hex_chat, :observability, :operation, :stop]
      ],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end
end
