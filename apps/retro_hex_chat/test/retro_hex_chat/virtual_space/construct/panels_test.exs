defmodule RetroHexChat.VirtualSpace.Construct.PanelsTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.Pins
  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.{Attachment, Attachments, Queries, UploadedFile}
  alias RetroHexChat.Repo
  alias RetroHexChat.VirtualSpace.Construct.Panels

  defp channel_with(members) do
    channel = "#panels-#{System.unique_integer([:positive])}"
    {:ok, pid} = ChannelSupervisor.start_child(channel)
    Enum.each(members, &({:ok, _} = Server.join(channel, &1)))

    on_exit(fn ->
      case ChannelRegistry.lookup(channel) do
        {:ok, ^pid} -> ChannelSupervisor.stop_child(pid)
        _gone -> :ok
      end
    end)

    channel
  end

  defp line(channel, author, content) do
    {:ok, message} =
      Queries.insert_message(%{channel_name: channel, author_nickname: author, content: content})

    message
  end

  defp picture(attrs, filename) do
    {:ok, file, _meta} =
      Attachments.prepare_direct_upload("ana", %{
        filename: filename,
        content_type: "image/png",
        byte_size: 10
      })

    from(f in UploadedFile, where: f.id == ^file.id)
    |> Repo.update_all(set: [preview_kind: "image", preview_status: "ready"])

    %Attachment{}
    |> Attachment.changeset(
      Map.merge(%{file_id: file.id, display_filename: filename, position: 0}, attrs)
    )
    |> Repo.insert!()
  end

  describe "a board" do
    test "shows the channel's topic and its pinned lines" do
      channel = channel_with(["ana"])
      Server.set_topic(channel, "ana", "Movie night")
      pinned = line(channel, "bob", "Bring snacks")
      {:ok, _pin} = Pins.pin(channel, pinned.id, "ana")

      board = Panels.fill(%{kind: "board"}, {:channel, channel}, "ana")
      assert board.topic == "Movie night"
      assert [%{author: "bob", text: "Bring snacks"}] = board.pins
    end
  end

  describe "a screen" do
    test "shows the newest picture still standing in the channel" do
      channel = channel_with(["ana"])
      picture(%{message_id: line(channel, "ana", "old").id}, "old.png")
      newest = picture(%{message_id: line(channel, "bob", "new").id}, "new.png")
      picture(%{message_id: line("#elsewhere", "ana", "x").id}, "elsewhere.png")

      assert %{image: %{id: id, filename: "new.png", author: "bob"}} =
               Panels.fill(%{kind: "screen"}, {:channel, channel}, "ana")

      assert id == newest.id
    end

    test "in a private Construct, shows only the pair's own pictures" do
      {:ok, pm} =
        Queries.insert_private_message(%{
          sender_nickname: "Ana",
          recipient_nickname: "bob",
          content: "look"
        })

      picture(%{private_message_id: pm.id}, "ours.png")

      assert %{image: %{filename: "ours.png"}} =
               Panels.fill(%{kind: "screen"}, {:direct_message, ["ana", "bob"]}, "ana")

      assert %{image: nil} =
               Panels.fill(%{kind: "screen"}, {:direct_message, ["ana", "cid"]}, "ana")
    end
  end

  describe "a sign" do
    test "may be rewritten by its author and by an operator, by nobody else" do
      channel = channel_with(["ana", "bob", "cid"])
      sign = %{kind: "sign", placed_by: "bob"}

      assert %{can_edit: true} = Panels.fill(sign, {:channel, channel}, "Bob")
      # The first to join a channel holds it.
      assert %{can_edit: true} = Panels.fill(sign, {:channel, channel}, "ana")
      assert %{can_edit: false} = Panels.fill(sign, {:channel, channel}, "cid")
      assert %{can_edit: true} = Panels.fill(sign, {:direct_message, ["cid", "dee"]}, "cid")
    end
  end
end
