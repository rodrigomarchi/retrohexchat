defmodule RetroHexChat.Jobs.ResultMetadataTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Jobs.ResultMetadata

  describe "error_reason/1" do
    test "names a changeset without inspecting it" do
      assert "changeset_error" = ResultMetadata.error_reason(%Ecto.Changeset{})
    end

    test "names atoms and passes binaries through" do
      assert "not_found" = ResultMetadata.error_reason(:not_found)
      assert "boom" = ResultMetadata.error_reason("boom")
    end

    test "names any other struct by its last module segment" do
      assert "RuntimeError" = ResultMetadata.error_reason(%RuntimeError{})
    end

    test "falls back to a fixed label rather than an inspected term" do
      assert "unknown" = ResultMetadata.error_reason({:tuple, :of, :things})
      assert "unknown" = ResultMetadata.error_reason(42)
    end
  end

  describe "error/1" do
    test "shapes the failure metadata" do
      assert %{result: "error", reason: "not_found"} = ResultMetadata.error(:not_found)
    end
  end

  describe "expiry/1" do
    test "counts an expiry" do
      assert %{result: "expired", expired_count: 1} = ResultMetadata.expiry({:ok, :expired})
    end

    test "names any other ok result" do
      assert %{result: "noop"} = ResultMetadata.expiry({:ok, :noop})
    end

    test "carries the snooze delay" do
      assert %{result: "snooze", seconds: 30} = ResultMetadata.expiry({:snooze, 30})
    end

    test "carries the cancellation reason" do
      assert %{result: "cancel", reason: "mute not found"} =
               ResultMetadata.expiry({:cancel, "mute not found"})
    end

    test "delegates errors to the shared reason" do
      assert %{result: "error", reason: "changeset_error"} =
               ResultMetadata.expiry({:error, %Ecto.Changeset{}})

      assert %{result: "error", reason: "timeout"} = ResultMetadata.expiry({:error, :timeout})
    end
  end
end
