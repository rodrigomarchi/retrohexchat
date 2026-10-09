defmodule RetroHexChat.Commands.TimestampTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Timestamp

  test "writes a moment in UTC to the minute, never the raw ISO stamp" do
    {:ok, datetime, 0} = DateTime.from_iso8601("2026-10-08T16:19:14.379859Z")

    assert Timestamp.format(datetime) == "2026-10-08 16:19 UTC"
  end

  test "writes a naive moment the same way" do
    assert Timestamp.format(~N[2026-10-08 16:19:14.379859]) == "2026-10-08 16:19 UTC"
  end

  test "says it does not know when there is no moment" do
    assert Timestamp.format(nil) == "unknown"
  end
end
