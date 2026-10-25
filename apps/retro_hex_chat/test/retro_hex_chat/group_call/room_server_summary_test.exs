defmodule RetroHexChat.GroupCall.RoomServerSummaryTest do
  @moduledoc """
  A conference closing while somebody asks about it.

  The chat of everybody in the channel asks a room for its summary to draw the
  badge, and the room can stop between being found and being asked. That is
  the room not being there, the same answer as never finding it, so the caller
  falls back to what the database says instead of crashing.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.GroupCall.Registry, as: GroupRegistry
  alias RetroHexChat.GroupCall.RoomServer

  test "a room that stops while it is being asked is not found" do
    token = "summary-race-#{System.unique_integer([:positive])}"
    parent = self()

    # Stands in for the room: registered under its token, and gone the moment
    # the question arrives. Linked, so a registration that fails fails the test
    # instead of leaving it waiting.
    room =
      spawn_link(fn ->
        {:ok, _owner} =
          Registry.register(GroupRegistry.room_registry_name(), {:room, token}, nil)

        send(parent, :registered)

        receive do
          {:"$gen_call", _from, :summary} -> exit(:normal)
        end
      end)

    # A loaded machine can take longer than the default second to schedule it.
    assert_receive :registered, 5_000
    assert {:ok, ^room} = GroupRegistry.lookup_room({:room, token})

    assert RoomServer.summary(token) == {:error, :not_found}
  end
end
