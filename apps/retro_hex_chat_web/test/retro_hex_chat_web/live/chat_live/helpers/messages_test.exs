defmodule RetroHexChatWeb.ChatLive.Helpers.MessagesTest do
  use ExUnit.Case, async: true

  alias RetroHexChatWeb.ChatLive.Helpers.Messages

  describe "stream_type/1" do
    test "keeps renderable persisted message types" do
      assert Messages.stream_type("message") == :message
      assert Messages.stream_type("action") == :action
      assert Messages.stream_type("p2p_invite") == :p2p_invite
      assert Messages.stream_type(:notice) == :notice
    end

    test "falls back for removed or unknown persisted message types" do
      assert Messages.stream_type("space_invite") == :message
      assert Messages.stream_type(:space_invite) == :message
      assert Messages.stream_type("future_type") == :message
      assert Messages.stream_type(nil) == :message
    end
  end

  describe "from_system?/1" do
    test "a channel's system line is the application talking" do
      assert Messages.from_system?(%{type: :system})
      assert Messages.from_system?(%{type: "system"})
    end

    test "a private conversation's system line is too, under its own name" do
      assert Messages.from_system?(%{type: :p2p_system})
      assert Messages.from_system?(%{type: "p2p_system"})
    end

    test "everything a person can write is not" do
      for type <- [:message, :action, :notice, :service, :error, :p2p_invite] do
        refute Messages.from_system?(%{type: type})
        refute Messages.from_system?(%{type: Atom.to_string(type)})
      end
    end

    test "a payload that states no type is not the system" do
      refute Messages.from_system?(%{})
      refute Messages.from_system?(%{type: nil})
    end
  end

  describe "cleared_from_channel?/3" do
    @cutoff ~U[2026-07-08 12:00:00Z]
    @channel "#lobby"

    defp socket_with_cutoff(cutoffs) do
      %Phoenix.LiveView.Socket{assigns: %{cleared_channel_cutoffs: cutoffs}}
    end

    test "a channel the reader never cleared hides nothing" do
      socket = socket_with_cutoff(%{})

      refute Messages.cleared_from_channel?(socket, @channel, %{timestamp: @cutoff})
    end

    test "a message written before the cutoff is hidden" do
      socket = socket_with_cutoff(%{@channel => @cutoff})
      before = DateTime.add(@cutoff, -1, :second)

      assert Messages.cleared_from_channel?(socket, @channel, %{timestamp: before})
      assert Messages.cleared_from_channel?(socket, @channel, %{inserted_at: before})
    end

    test "a message written at the cutoff is hidden, since clearing includes it" do
      socket = socket_with_cutoff(%{@channel => @cutoff})

      assert Messages.cleared_from_channel?(socket, @channel, %{timestamp: @cutoff})
    end

    test "a message written after the cutoff is shown" do
      socket = socket_with_cutoff(%{@channel => @cutoff})
      later = DateTime.add(@cutoff, 1, :second)

      assert Messages.cleared_from_channel?(socket, @channel, %{timestamp: later}) == false
      assert Messages.cleared_from_channel?(socket, @channel, %{inserted_at: later}) == false
    end

    test "both spellings of the moment answer the same way" do
      socket = socket_with_cutoff(%{@channel => @cutoff})
      before = DateTime.add(@cutoff, -1, :second)

      assert Messages.cleared_from_channel?(socket, @channel, %{timestamp: before}) ==
               Messages.cleared_from_channel?(socket, @channel, %{inserted_at: before})
    end

    test "a naive moment is compared against a cutoff of either kind" do
      naive = NaiveDateTime.add(DateTime.to_naive(@cutoff), -1, :second)

      assert Messages.cleared_from_channel?(
               socket_with_cutoff(%{@channel => @cutoff}),
               @channel,
               %{inserted_at: naive}
             )

      assert Messages.cleared_from_channel?(
               socket_with_cutoff(%{@channel => DateTime.to_naive(@cutoff)}),
               @channel,
               %{inserted_at: naive}
             )
    end

    test "a message that states no moment is shown rather than swallowed" do
      socket = socket_with_cutoff(%{@channel => @cutoff})

      refute Messages.cleared_from_channel?(socket, @channel, %{content: "no timestamp"})
      refute Messages.cleared_from_channel?(socket, @channel, %{timestamp: nil})
    end

    test "a cutoff on one channel does not hide another channel's messages" do
      socket = socket_with_cutoff(%{@channel => @cutoff})
      before = DateTime.add(@cutoff, -1, :second)

      refute Messages.cleared_from_channel?(socket, "#other", %{timestamp: before})
    end
  end
end
