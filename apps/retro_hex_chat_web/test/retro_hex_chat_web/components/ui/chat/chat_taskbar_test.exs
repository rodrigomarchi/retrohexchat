defmodule RetroHexChatWeb.Components.UI.ChatTaskbarTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.UI.ChatTaskbar

  @moduletag :unit

  defp taskbar(open_ids, opts \\ []) do
    render_component(
      &ChatTaskbar.chat_taskbar/1,
      Keyword.merge(
        [
          chat_label: "#lobby[alice]",
          open_windows: MapSet.new(open_ids),
          is_admin: Keyword.get(opts, :is_admin, false)
        ],
        Keyword.delete(opts, :is_admin)
      )
    )
  end

  # Mirrors what chat_taskbar/1 feeds the grouper, without rendering: the order
  # of this list is the order the taskbar would render.
  defp slots(ids) do
    ids
    |> Enum.map(&%{id: &1, label: &1, icon_fn: :icon_chat})
    |> ChatTaskbar.group_windows()
  end

  describe "group_windows/1" do
    test "a lone family member keeps its own button" do
      assert [%{kind: :window, window: %{id: "profile"}}] = slots(["profile"])
    end

    test "two or more collapse into one group, in the first member's position" do
      assert [
               %{kind: :window, window: %{id: "chat"}},
               %{kind: :group, family: :account, windows: members}
             ] = slots(["chat", "account", "away"])

      assert Enum.map(members, & &1.id) == ["account", "away"]
    end

    test "windows outside any family are never grouped" do
      assert [%{kind: :window}, %{kind: :window}] = slots(["chat", "cheatsheet"])
    end

    test "the group takes the position of its first member, not the last" do
      assert [
               %{kind: :group, family: :admin},
               %{kind: :window, window: %{id: "timers"}}
             ] = slots(["admin-users", "admin-motd", "timers"])
    end

    test "distinct families stay distinct" do
      assert [
               %{kind: :group, family: :account},
               %{kind: :group, family: :contacts}
             ] = slots(["account", "profile", "address-book", "nick-colors"])
    end
  end

  describe "rendering" do
    test "renders a group trigger once two family windows are open" do
      html = taskbar(["account", "away"])

      assert html =~ ~s(data-testid="taskbar-group-account")
      assert html =~ "data-taskbar-group-panel"
    end

    test "renders a plain button while only one family window is open" do
      html = taskbar(["account"])

      refute html =~ ~s(data-testid="taskbar-group-account")
      assert html =~ ~s(data-window-taskbar="account")
    end

    test "the group panel still carries one taskbar button per window" do
      html = taskbar(["account", "away", "user-modes"])

      assert html =~ ~s(data-window-taskbar="account")
      assert html =~ ~s(data-window-taskbar="away")
      assert html =~ ~s(data-window-taskbar="user-modes")
    end

    test "the mobile task switcher keeps the flat list — it scrolls already" do
      html = taskbar(["account", "away"])

      assert html =~ "data-mobile-task-switcher"
    end

    test "the chat button is named after the conversation, like the window" do
      html = taskbar([], chat_label: "#retro[alice]")

      assert html =~ "#retro[alice]"
    end
  end
end
