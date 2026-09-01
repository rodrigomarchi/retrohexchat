defmodule RetroHexChatWeb.ChatLive.GroupCallReadModelTest do
  @moduledoc """
  What the chat keeps about a call it is not in.

  This is the half of the group-call adapter that stays behind when the
  conference moves to a surface of its own: the tab bar, the sidebar badge and
  the live card all read it, and none of them require the reader to be in the
  call. The rule it encodes is the one from the wave-2 plan — if the datum
  exists for someone who is only looking at the channel, it lives here.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias Phoenix.Component
  alias Phoenix.LiveView.Socket
  alias RetroHexChatWeb.ChatLive.GroupCallReadModel, as: ReadModel

  defp socket(assigns \\ %{}), do: Component.assign(%Socket{}, assigns)

  defp session_socket(channels) do
    socket(%{session: %{nickname: "ana", channels: channels, identified: true}})
  end

  describe "mark_active/3" do
    test "a channel with a call is in the set and carries a normalised summary" do
      socket = ReadModel.mark_active(socket(), "#retro", %{"room" => %{"token" => "tok"}})

      assert MapSet.member?(ReadModel.channels(socket), "#retro")
      assert ReadModel.summary(socket, "#retro").room.token == "tok"
      assert ReadModel.summary(socket, "#retro").room.channel_name == "#retro"
      assert ReadModel.summary(socket, "#retro").participants == []
    end

    test "a channel name that is not a name changes nothing" do
      assert ReadModel.mark_active(socket(), nil, %{}) |> ReadModel.channels() |> Enum.empty?()
    end
  end

  describe "mark_inactive/2" do
    test "the call ending clears both the badge and the summary" do
      socket =
        socket()
        |> ReadModel.mark_active("#retro", %{"room" => %{"token" => "tok"}})
        |> ReadModel.mark_inactive("#retro")

      assert ReadModel.channels(socket) |> Enum.empty?()
      assert ReadModel.summary(socket, "#retro") == nil
    end

    test "clearing a channel leaves the others alone" do
      socket =
        socket()
        |> ReadModel.mark_active("#retro", %{})
        |> ReadModel.mark_active("#elixir", %{})
        |> ReadModel.mark_inactive("#retro")

      assert MapSet.to_list(ReadModel.channels(socket)) == ["#elixir"]
    end
  end

  describe "reading before anything was written" do
    test "a socket that never saw a call reads empty, not nil" do
      assert ReadModel.channels(socket()) == MapSet.new()
      assert ReadModel.summaries(socket()) == %{}
      assert ReadModel.summary(socket(), "#retro") == nil
      assert ReadModel.live_summaries(socket()) == []
    end
  end

  describe "live_summaries/1" do
    # Order matters because the reconnect path picks the first channel whose
    # call still holds this nickname. The names here are deliberately out of
    # alphabetical order: a small map sorts its keys, so a version that read
    # the map directly would pass on any list that happened to be sorted.
    test "follows the order the session lists its channels, not the map's" do
      socket =
        ["#zulu", "#mike", "#alfa"]
        |> session_socket()
        |> ReadModel.mark_active("#alfa", %{})
        |> ReadModel.mark_active("#zulu", %{})

      assert ReadModel.live_summaries(socket) |> Enum.map(&elem(&1, 0)) == ["#zulu", "#alfa"]
    end

    # A summary can outlive the session's list of channels: parting drops the
    # channel before the broadcast that ends the call arrives.
    test "ignores a summary for a channel the session no longer lists" do
      socket =
        ["#retro"]
        |> session_socket()
        |> ReadModel.mark_active("#retro", %{})
        |> ReadModel.mark_active("#gone", %{})

      assert ReadModel.live_summaries(socket) |> Enum.map(&elem(&1, 0)) == ["#retro"]
    end

    test "a session without channels has nothing live" do
      assert ReadModel.live_summaries(socket(%{session: %{nickname: "ana"}})) == []
    end
  end

  describe "refresh_all/1" do
    test "a socket with no session is left alone" do
      assert ReadModel.refresh_all(socket()) |> ReadModel.channels() == MapSet.new()
    end
  end

  describe "elsewhere/3" do
    defp summaries(pairs) do
      Map.new(pairs, fn {channel, token} ->
        {channel, %{room: %{token: token, channel_name: channel}}}
      end)
    end

    test "names the channel whose call this person has open at its own address" do
      assert ReadModel.elsewhere(
               ["#retro"],
               summaries([{"#retro", "tok"}]),
               MapSet.new(["/call/tok"])
             ) == %{channel_name: "#retro", path: "/call/tok"}
    end

    test "a live call with no tab of its own is not somewhere else" do
      assert ReadModel.elsewhere(
               ["#retro"],
               summaries([{"#retro", "tok"}]),
               MapSet.new(["/chat"])
             ) ==
               nil
    end

    test "a tab for a call this person's channels do not carry is not theirs to name" do
      assert ReadModel.elsewhere(["#retro"], %{}, MapSet.new(["/call/tok"])) == nil
    end

    # Two calls in two tabs is one zone and one line, so which one it names has
    # to be the same answer every render — the session's channel order, never a
    # map's.
    test "picks by the session's channel order and not by hashing" do
      summaries = summaries([{"#retro", "one"}, {"#lobby", "two"}])
      open = MapSet.new(["/call/one", "/call/two"])

      assert ReadModel.elsewhere(["#lobby", "#retro"], summaries, open).channel_name == "#lobby"
      assert ReadModel.elsewhere(["#retro", "#lobby"], summaries, open).channel_name == "#retro"
    end

    test "a summary with no room token has no address to go to" do
      assert ReadModel.elsewhere(
               ["#retro"],
               %{"#retro" => %{room: %{token: nil}}},
               MapSet.new(["/call/tok"])
             ) == nil
    end
  end
end
