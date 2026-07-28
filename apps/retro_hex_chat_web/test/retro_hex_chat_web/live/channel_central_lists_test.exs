defmodule RetroHexChatWeb.ChannelCentralListsTest do
  @moduledoc """
  The ban/exception lists Channel Central draws.

  These are the channel process's own sets of masks, not database rows — bans
  are persisted only for registered channels, so the process is the authority
  for what a moderator sees. They cannot be paginated by cursor, so the contract
  is the other one the plan allows: a ceiling that the window **discloses**.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @moduletag :unit

  alias RetroHexChatWeb.ChatLive.Components.ChannelCentralDialog
  alias RetroHexChatWeb.Components.UI.ListStates

  defp state_with(list_type, count) do
    masks = for i <- 1..count, into: MapSet.new(), do: "masked#{i}!*@*"

    %{bans: MapSet.new(), ban_exceptions: MapSet.new(), invite_exceptions: MapSet.new()}
    |> Map.put(list_type, masks)
  end

  describe "the render ceiling" do
    test "a short list is shown whole and reports its true size" do
      %{entries: entries, total: total} =
        ChannelCentralDialog.channel_central_list_entries(state_with(:bans, 3), "bans")

      assert length(entries) == 3
      assert total == 3
    end

    test "a pathological list is capped, and the total still tells the truth" do
      # The counter must come from what the channel holds, never from the rows
      # that survived the cap — that is the mistake this refactor exists to undo.
      %{entries: entries, total: total} =
        ChannelCentralDialog.channel_central_list_entries(state_with(:bans, 250), "bans")

      assert length(entries) == 200
      assert total == 250
    end

    test "each list type is capped on its own" do
      for {key, type} <- [
            {:bans, "bans"},
            {:ban_exceptions, "ban_exceptions"},
            {:invite_exceptions, "invite_exceptions"}
          ] do
        %{entries: entries, total: total} =
          ChannelCentralDialog.channel_central_list_entries(state_with(key, 250), type)

        assert length(entries) == 200, "#{type} was not capped"
        assert total == 250, "#{type} lost its true size"
      end
    end

    test "a channel with no state at all renders nothing rather than raising" do
      assert %{entries: [], total: 0} =
               ChannelCentralDialog.channel_central_list_entries(nil, "bans")
    end
  end

  describe "the truncation strip" do
    test "appears only once the list is actually longer than the window shows" do
      html =
        render_component(&ListStates.list_count_strip/1,
          shown: 200,
          total: 250
        )

      assert html =~ "200"
      assert html =~ "250"
    end

    test "stays out of the way when nothing is hidden" do
      html =
        render_component(&ListStates.list_count_strip/1,
          shown: 3,
          total: 3
        )

      refute html =~ "list-count-strip"
    end
  end
end
