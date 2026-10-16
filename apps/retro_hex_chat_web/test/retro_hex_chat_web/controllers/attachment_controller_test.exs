defmodule RetroHexChatWeb.AttachmentControllerTest do
  use RetroHexChatWeb.ConnCase

  @moduletag :integration

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.{Attachments, Service}
  alias RetroHexChatWeb.App.Paths

  defp uploaded_file(owner, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          filename: "download.txt",
          content_type: "text/plain",
          byte_size: 18
        },
        attrs
      )

    {:ok, file, _meta} = Attachments.prepare_direct_upload(owner, attrs)
    {:ok, [file]} = Attachments.confirm_uploaded_files([file.id], owner)
    file
  end

  test "sends a visitor's download to sign in", %{conn: conn} do
    conn = get(conn, ~p"/chat/attachments/123")
    assert redirected_to(conn) == Paths.visitor_sign_in_path(:links, "/")
  end

  describe "a visitor's preview" do
    setup do
      channel = "#vis#{System.unique_integer([:positive])}"
      {:ok, pid} = ChannelSupervisor.ensure_started(channel)
      on_exit(fn -> if Process.alive?(pid), do: ChannelSupervisor.stop_child(pid) end)
      {:ok, _} = Server.join(channel, "Alice")
      file = uploaded_file("Alice", %{filename: "screen.png", content_type: "image/png"})

      {:ok, message} =
        Service.send_message(channel, "Alice", "file", "message", attachment_ids: [file.id])

      %{channel: channel, upload: file, attachment: hd(message.attachments)}
    end

    test "shows the picture in a channel a visitor may watch", ctx do
      conn = get(build_conn(), ~p"/chat/attachments/#{ctx.attachment.id}/preview")

      assert redirected_to(conn) ==
               "http://storage.test/#{ctx.upload.storage_bucket}/#{ctx.upload.storage_key}"
    end

    test "shows nothing from a channel a stranger may not see", ctx do
      :ok = Server.set_mode(ctx.channel, "Alice", "+s")

      conn = get(build_conn(), ~p"/chat/attachments/#{ctx.attachment.id}/preview")

      assert conn.status == 404
    end
  end

  test "redirects channel attachment downloads to a signed storage URL", %{conn: conn} do
    file = uploaded_file("Alice")

    {:ok, message} =
      Service.send_message("#docs", "Alice", "file", "message", attachment_ids: [file.id])

    attachment = hd(message.attachments)

    conn =
      conn
      |> chat_conn("Alice")
      |> get(~p"/chat/attachments/#{attachment.id}")

    assert redirected_to(conn) == "http://storage.test/#{file.storage_bucket}/#{file.storage_key}"
  end

  test "redirects safe inline previews to a signed storage URL", %{conn: conn} do
    file = uploaded_file("Alice", %{filename: "screen.png", content_type: "image/png"})

    {:ok, message} =
      Service.send_message("#docs", "Alice", "file", "message", attachment_ids: [file.id])

    attachment = hd(message.attachments)

    conn =
      conn
      |> chat_conn("Alice")
      |> get(~p"/chat/attachments/#{attachment.id}/preview")

    assert redirected_to(conn) == "http://storage.test/#{file.storage_bucket}/#{file.storage_key}"
    assert get_resp_header(conn, "cache-control") == ["private, max-age=60"]
  end

  test "does not preview unsafe or non-inline attachments", %{conn: conn} do
    file = uploaded_file("Alice", %{filename: "icon.svg", content_type: "image/svg+xml"})

    {:ok, message} =
      Service.send_message("#docs", "Alice", "file", "message", attachment_ids: [file.id])

    attachment = hd(message.attachments)

    conn =
      conn
      |> chat_conn("Alice")
      |> get(~p"/chat/attachments/#{attachment.id}/preview")

    assert response(conn, 404) == ""
  end

  test "hides private attachments from non-participants", %{conn: conn} do
    file = uploaded_file("Alice")

    {:ok, message} =
      Service.send_private_message("Alice", "Bob", "file", "message", attachment_ids: [file.id])

    attachment = hd(message.attachments)

    conn =
      conn
      |> chat_conn("Eve")
      |> get(~p"/chat/attachments/#{attachment.id}")

    assert response(conn, 404) == ""
  end
end
