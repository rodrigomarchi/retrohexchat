defmodule RetroHexChatWeb.App.GroupCallShapeTest do
  @moduledoc """
  The normalisers a call's payloads pass through, tested for the first time.

  They were private to the chat's group-call adapter, so the only thing that
  ever exercised them was a full LiveView flow. What they actually cope with is
  three sources spelling the same field three ways — a struct, a broadcast with
  string keys, and a partial update from the browser — and that is what is
  asserted here.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChatWeb.App.GroupCallShape, as: Shape

  describe "value/2" do
    test "reads a field however the source spelled it" do
      assert Shape.value(%{token: "t"}, :token) == "t"
      assert Shape.value(%{"token" => "t"}, :token) == "t"
    end

    test "a missing field and a missing map are both nil" do
      assert Shape.value(%{}, :token) == nil
      assert Shape.value(nil, :token) == nil
    end

    # An atom key wins over a string one, because a struct from the database is
    # the more authoritative of the two sources.
    test "prefers the atom spelling when a payload carries both" do
      assert Shape.value(%{:token => "atom", "token" => "string"}, :token) == "atom"
    end
  end

  describe "normalize_room/1" do
    test "keeps every field the renderer reads, present or not" do
      room = Shape.normalize_room(%{"token" => "t", "channel_name" => "#retro"})

      assert room.token == "t"
      assert room.channel_name == "#retro"
      assert Map.has_key?(room, :status)
      assert Map.has_key?(room, :max_participants)
      assert room.metadata == %{}
    end

    test "no room at all stays no room" do
      assert Shape.normalize_room(nil) == nil
    end
  end

  describe "normalize_participants/1" do
    test "a missing list is an empty one, never nil" do
      assert Shape.normalize_participants(nil) == []
    end

    test "normalises each entry" do
      assert [%{id: 1, nickname: "ana"}] =
               Shape.normalize_participants([%{"id" => 1, "nickname" => "ana"}])
    end

    test "a participant with nothing in it still has the shape a tile reads" do
      participant = Shape.normalize_participant(nil)

      assert participant.id == nil
      assert participant.media_state == %{}
    end
  end

  describe "normalize_id/1" do
    test "accepts what the browser sends as a string" do
      assert Shape.normalize_id("42") == 42
      assert Shape.normalize_id(42) == 42
    end

    test "refuses what is not an id" do
      assert Shape.normalize_id("abc") == nil
      assert Shape.normalize_id(nil) == nil
    end
  end

  describe "truthy?/1" do
    # The browser sends checkbox state as "on", a JSON payload sends true, and a
    # form sends "1". All three mean yes.
    test "accepts every spelling of yes" do
      for value <- [true, "true", "on", "1", 1] do
        assert Shape.truthy?(value), "expected #{inspect(value)} to be truthy"
      end
    end

    test "everything else is no" do
      for value <- [false, "false", "off", "0", 0, nil, "yes"] do
        refute Shape.truthy?(value), "expected #{inspect(value)} to be falsy"
      end
    end
  end

  describe "normalize_console_section/1" do
    test "accepts the sections that exist" do
      assert Shape.normalize_console_section("people") == :people
      assert Shape.normalize_console_section(:stats) == :stats
    end

    test "anything else lands on the call itself" do
      assert Shape.normalize_console_section("nope") == :call
      assert Shape.normalize_console_section(nil) == :call
    end
  end

  describe "reaction_emoji/1" do
    test "each named reaction draws a different thing" do
      names = ~w(heart thumbs_up clap laugh wow)
      drawn = Enum.map(names, &Shape.reaction_emoji/1)

      assert length(Enum.uniq(drawn)) == length(names)
    end

    # A reaction the server does not know still has to render as something: a
    # blank bubble on a video tile reads as a bug rather than as a reaction.
    test "an unknown reaction falls back rather than blank" do
      assert Shape.reaction_emoji("nonsense") == Shape.reaction_emoji("heart")
    end
  end

  describe "normalize_pinned_participant_ids/1" do
    test "keeps ids and drops what is not one" do
      assert Shape.normalize_pinned_participant_ids(["1", 2, "x", nil]) == [1, 2]
    end

    test "anything that is not a list is no pins" do
      assert Shape.normalize_pinned_participant_ids(nil) == []
      assert Shape.normalize_pinned_participant_ids("1") == []
    end
  end
end
