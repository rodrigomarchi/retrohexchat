defmodule RetroHexChat.Chat.ReconnectReadMarkersTest do
  @moduledoc """
  Where somebody had got to in each conversation.

  Stored beside what they had open, because it is the same fact: this table
  answers "what was on this person's screen", and how far down they had read is
  part of that answer.

  Everything asserted here is about the map surviving contact with whatever the
  client sends. A snapshot is written by a browser, so it can arrive with a key
  that is not a conversation, a value that is not an id, or ten thousand
  entries — and the one thing that must never happen is a malformed snapshot
  taking the mount down with it.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.ReconnectState
  alias RetroHexChat.Services.RegisteredNick

  describe "normalize/1" do
    test "keeps a channel marker and a private one" do
      markers = normalize(%{"#lobby" => 42, "pm:ana" => 7})

      assert markers == %{"#lobby" => 42, "pm:ana" => 7}
    end

    test "starts empty when there is nothing to normalize" do
      assert normalize(nil) == %{}
      assert ReconnectState.new().read_markers == %{}
    end

    # A key that is not a conversation is a key nothing will ever look up, and
    # it would sit in the row forever.
    test "drops a key that is not a conversation" do
      markers = normalize(%{"lobby" => 1, "" => 2, "#ok" => 3})

      assert markers == %{"#ok" => 3}
    end

    test "drops a value that is not a message id" do
      markers = normalize(%{"#a" => "42", "#b" => -1, "#c" => 0, "#d" => nil, "#e" => 9})

      assert markers == %{"#e" => 9}
    end

    test "caps the map so a runaway snapshot cannot grow the row without bound" do
      many = Map.new(1..500, fn i -> {"#c#{i}", i} end)

      assert map_size(normalize(many)) == ReconnectState.max_read_markers()
    end
  end

  describe "save and load" do
    test "a marker survives the round trip" do
      owner = register("Marked")

      :ok =
        ReconnectState.save(owner, %{
          channels: ["#lobby"],
          open_pm_tabs: [],
          welcomed_channels: [],
          read_markers: %{"#lobby" => 99}
        })

      assert {:ok, %{read_markers: %{"#lobby" => 99}}} = ReconnectState.load(owner)
    end

    test "a snapshot written before markers existed loads as empty" do
      owner = register("Legacy")

      :ok =
        ReconnectState.save(owner, %{
          channels: ["#lobby"],
          open_pm_tabs: [],
          welcomed_channels: []
        })

      assert {:ok, %{read_markers: %{}}} = ReconnectState.load(owner)
    end

    # A marker for a channel somebody left is exactly what they want when they
    # rejoin tomorrow, so leaving a conversation does not throw it away. What
    # keeps the map from growing forever is the cap, not a cleanup.
    test "a marker survives leaving the conversation" do
      owner = register("Left")

      :ok =
        ReconnectState.save(owner, %{
          channels: [],
          open_pm_tabs: [],
          welcomed_channels: [],
          read_markers: %{"#gone" => 2}
        })

      assert {:ok, %{read_markers: %{"#gone" => 2}}} = ReconnectState.load(owner)
    end
  end

  defp normalize(markers) do
    ReconnectState.normalize(%{read_markers: markers}).read_markers
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
