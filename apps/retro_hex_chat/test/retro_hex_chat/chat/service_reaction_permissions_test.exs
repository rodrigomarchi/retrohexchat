defmodule RetroHexChat.Chat.ServiceReactionPermissionsTest do
  @moduledoc """
  Who may put a reaction on a line.

  A channel line is answered under the room's rule for speaking, except that a
  reaction always needs a seat in the room: a moderated room asks for voice,
  and a member the operators muted is muted here too. A private line is
  answered only by the two people in the conversation.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Admin.GlobalMutes
  alias RetroHexChat.Channels.{Server, Supervisor}
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Chat.Reactions
  alias RetroHexChat.Chat.Service
  alias RetroHexChat.Services.RegisteredNick

  @thumbs "\u{1F44D}"

  setup do
    channel = "#react-#{System.unique_integer([:positive])}"
    {:ok, pid} = Supervisor.start_child(channel)
    on_exit(fn -> if Process.alive?(pid), do: Supervisor.stop_child(pid) end)

    member = register("member")
    {:ok, _} = Server.join(channel, "op")
    {:ok, _} = Server.join(channel, member)
    {:ok, message_id} = Server.send_message(channel, "op", "worth reacting to")

    %{channel: channel, member: member, message: Queries.get_message(message_id)}
  end

  describe "on a channel line" do
    test "a member reacts", ctx do
      assert {:ok, %{count: 1}} = Service.toggle_reaction(ctx.message.id, ctx.member, @thumbs)
    end

    test "somebody outside the room does not", ctx do
      assert {:error, _reason} = Service.toggle_reaction(ctx.message.id, "outsider", @thumbs)
      assert Reactions.summary_for(ctx.message) == %{}
    end

    test "somebody who left the room no longer does", ctx do
      :ok = Server.part(ctx.channel, ctx.member)

      assert {:error, _reason} = Service.toggle_reaction(ctx.message.id, ctx.member, @thumbs)
    end

    test "a muted member does not", ctx do
      :ok = Server.channel_mute(ctx.channel, "op", ctx.member, 60)

      assert {:error, reason} = Service.toggle_reaction(ctx.message.id, ctx.member, @thumbs)
      assert reason =~ "muted"
    end

    test "a moderated room asks for voice", ctx do
      :ok = Server.set_mode(ctx.channel, "op", "+m")

      assert {:error, reason} = Service.toggle_reaction(ctx.message.id, ctx.member, @thumbs)
      assert reason =~ "+v"
      assert reason =~ "react"

      :ok = Server.set_mode(ctx.channel, "op", "+v", [ctx.member])

      assert {:ok, %{count: 1}} = Service.toggle_reaction(ctx.message.id, ctx.member, @thumbs)
    end

    test "a member muted by an administrator does not", ctx do
      :ok = GlobalMutes.mute(ctx.member)
      on_exit(fn -> GlobalMutes.unmute(ctx.member) end)

      assert {:error, _reason} = Service.toggle_reaction(ctx.message.id, ctx.member, @thumbs)
    end

    # Nobody is kept stuck behind an answer they no longer mean: taking one's
    # own reaction back only needs the seat.
    test "a muted member can still take back their own reaction", ctx do
      {:ok, _} = Service.toggle_reaction(ctx.message.id, ctx.member, @thumbs)
      :ok = Server.channel_mute(ctx.channel, "op", ctx.member, 60)

      assert {:ok, %{count: 0}} = Service.toggle_reaction(ctx.message.id, ctx.member, @thumbs)
    end

    test "under +m an unvoiced member can still take back their own reaction", ctx do
      {:ok, _} = Service.toggle_reaction(ctx.message.id, ctx.member, @thumbs)
      :ok = Server.set_mode(ctx.channel, "op", "+m")

      assert {:ok, %{count: 0}} = Service.toggle_reaction(ctx.message.id, ctx.member, @thumbs)
    end

    test "somebody who left cannot take one back either", ctx do
      {:ok, _} = Service.toggle_reaction(ctx.message.id, ctx.member, @thumbs)
      :ok = Server.part(ctx.channel, ctx.member)

      assert {:error, _reason} = Service.toggle_reaction(ctx.message.id, ctx.member, @thumbs)
    end

    test "a room nobody is in refuses everybody", ctx do
      {:ok, message} =
        Queries.insert_message(%{
          channel_name: "#empty-#{System.unique_integer([:positive])}",
          author_nickname: "Writer",
          content: "nobody here",
          type: "message"
        })

      assert {:error, _reason} = Service.toggle_reaction(message.id, ctx.member, @thumbs)
    end
  end

  describe "on a private line" do
    setup do
      writer = register("writer")
      reader = register("reader")

      {:ok, pm} =
        Queries.insert_private_message(%{
          sender_nickname: writer,
          recipient_nickname: reader,
          content: "just between us",
          type: "message"
        })

      %{pm: pm, writer: writer, reader: reader, stranger: register("stranger")}
    end

    test "either person in the conversation reacts", ctx do
      assert {:ok, %{count: 1}} =
               Service.toggle_private_reaction(ctx.pm.id, ctx.reader, @thumbs)

      assert {:ok, %{count: 2}} = Service.toggle_private_reaction(ctx.pm.id, ctx.writer, @thumbs)
    end

    test "a third person does not", ctx do
      assert {:error, _reason} = Service.toggle_private_reaction(ctx.pm.id, ctx.stranger, @thumbs)
      assert Reactions.summary_for(ctx.pm) == %{}
    end
  end

  defp register(prefix) do
    nickname = "#{prefix}#{System.unique_integer([:positive])}" |> String.slice(0, 16)

    {:ok, _} =
      Repo.insert(%RegisteredNick{
        nickname: nickname,
        password_hash: "x",
        registered_at: DateTime.utc_now(),
        last_seen_at: DateTime.utc_now()
      })

    nickname
  end
end
