defmodule RetroHexChatWeb.Components.PerformDialogTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Chat.AutoJoinEntry
  alias RetroHexChat.Chat.PerformEntry
  alias RetroHexChatWeb.Components.PerformDialog

  @moduletag :component

  @base_assigns %{
    visible: true,
    active_tab: "commands",
    perform_entries: [],
    perform_selected: nil,
    perform_enabled: true,
    autojoin_entries: [],
    autojoin_selected: nil,
    show_perform_add_dialog: false,
    show_perform_edit_dialog: false,
    show_autojoin_add_dialog: false,
    show_autojoin_edit_dialog: false
  }

  defp render_dialog(overrides \\ %{}) do
    assigns = Map.merge(@base_assigns, overrides)
    render_component(&PerformDialog.perform_dialog/1, assigns)
  end

  describe "visibility" do
    @tag :unit
    test "renders when visible is true" do
      html = render_dialog()

      assert html =~ "perform-dialog"
      assert html =~ "Perform / Auto-Commands"
    end

    @tag :unit
    test "does not render when visible is false" do
      html = render_dialog(%{visible: false})

      refute html =~ "perform-dialog"
      refute html =~ "Perform / Auto-Commands"
    end

    @tag :unit
    test "renders close button" do
      html = render_dialog()

      assert html =~ "perform-dialog-close"
      assert html =~ "close_perform_dialog"
    end
  end

  describe "tab switching" do
    @tag :unit
    test "renders both tab labels" do
      html = render_dialog()

      assert html =~ "perform-tab-commands"
      assert html =~ "perform-tab-autojoin"
      assert html =~ "Commands"
      assert html =~ "Auto-Join"
    end

    @tag :unit
    test "commands tab is active by default" do
      html = render_dialog(%{active_tab: "commands"})

      assert html =~ "No perform commands configured"
      refute html =~ "No auto-join channels configured"
    end

    @tag :unit
    test "autojoin tab renders when active" do
      html = render_dialog(%{active_tab: "autojoin"})

      assert html =~ "No auto-join channels configured"
      refute html =~ "No perform commands configured"
    end

    @tag :unit
    test "commands tab has aria-selected when active" do
      html = render_dialog(%{active_tab: "commands"})

      # HEEx renders boolean attributes as bare (aria-selected, not aria-selected="true")
      assert html =~ ~s(role="tab" aria-selected)
    end

    @tag :unit
    test "tab click events are wired" do
      html = render_dialog()

      assert html =~ "perform_dialog_tab"
      assert html =~ ~s(phx-value-tab="commands")
      assert html =~ ~s(phx-value-tab="autojoin")
    end
  end

  describe "commands tab - empty state" do
    @tag :unit
    test "shows empty message when no entries" do
      html = render_dialog(%{active_tab: "commands", perform_entries: []})

      assert html =~ "perform-empty"
      assert html =~ "No perform commands configured"
    end

    @tag :unit
    test "shows table headers" do
      html = render_dialog(%{active_tab: "commands"})

      assert html =~ "#"
      assert html =~ "Command"
    end
  end

  describe "commands tab - with entries" do
    @tag :unit
    test "renders perform entries with position and command" do
      entries = [
        PerformEntry.new(command: "/join #elixir", position: 0),
        PerformEntry.new(command: "/msg hello world", position: 1)
      ]

      html = render_dialog(%{active_tab: "commands", perform_entries: entries})

      assert html =~ "perform-entry-0"
      assert html =~ "perform-entry-1"
      assert html =~ "/join #elixir"
      assert html =~ "/msg hello world"
      refute html =~ "perform-empty"
    end

    @tag :unit
    test "masks /ns identify password" do
      entries = [
        PerformEntry.new(command: "/ns identify secretpass", position: 0)
      ]

      html = render_dialog(%{active_tab: "commands", perform_entries: entries})

      assert html =~ "/ns identify ****"
      refute html =~ "secretpass"
    end

    @tag :unit
    test "masks /msg nickserv identify password" do
      entries = [
        PerformEntry.new(command: "/msg nickserv identify mypass123", position: 0)
      ]

      html = render_dialog(%{active_tab: "commands", perform_entries: entries})

      assert html =~ "/msg nickserv identify ****"
      refute html =~ "mypass123"
    end

    @tag :unit
    test "does not mask non-password commands" do
      entries = [
        PerformEntry.new(command: "/join #test", position: 0)
      ]

      html = render_dialog(%{active_tab: "commands", perform_entries: entries})

      assert html =~ "/join #test"
    end

    @tag :unit
    test "selected entry has highlight style" do
      entries = [
        PerformEntry.new(command: "/join #test", position: 0),
        PerformEntry.new(command: "/join #other", position: 1)
      ]

      html =
        render_dialog(%{
          active_tab: "commands",
          perform_entries: entries,
          perform_selected: 0
        })

      # The selected row should have the highlight background
      assert html =~ "background: #000080"
    end

    @tag :unit
    test "entries have click event for selection" do
      entries = [
        PerformEntry.new(command: "/join #test", position: 0)
      ]

      html = render_dialog(%{active_tab: "commands", perform_entries: entries})

      assert html =~ "perform_select"
      assert html =~ ~s(phx-value-position="0")
    end
  end

  describe "commands tab - button states" do
    @tag :unit
    test "add button is always enabled" do
      html = render_dialog(%{active_tab: "commands", perform_selected: nil})

      assert html =~ "perform-add-btn"
      assert html =~ "perform_dialog_add"
      # Add button should not be disabled
      refute Regex.match?(
               ~r/data-testid="perform-add-btn"[^>]*disabled/,
               html
             )
    end

    @tag :unit
    test "edit button is disabled when nothing selected" do
      html = render_dialog(%{active_tab: "commands", perform_selected: nil})

      assert html =~ "perform-edit-btn"

      assert Regex.match?(
               ~r/data-testid="perform-edit-btn"[^>]*disabled/,
               html
             )
    end

    @tag :unit
    test "edit button is enabled when entry is selected" do
      entries = [PerformEntry.new(command: "/join #test", position: 0)]

      html =
        render_dialog(%{
          active_tab: "commands",
          perform_entries: entries,
          perform_selected: 0
        })

      refute Regex.match?(
               ~r/data-testid="perform-edit-btn"[^>]*disabled/,
               html
             )
    end

    @tag :unit
    test "remove button is disabled when nothing selected" do
      html = render_dialog(%{active_tab: "commands", perform_selected: nil})

      assert html =~ "perform-remove-btn"

      assert Regex.match?(
               ~r/data-testid="perform-remove-btn"[^>]*disabled/,
               html
             )
    end

    @tag :unit
    test "remove button is enabled when entry is selected" do
      entries = [PerformEntry.new(command: "/join #test", position: 0)]

      html =
        render_dialog(%{
          active_tab: "commands",
          perform_entries: entries,
          perform_selected: 0
        })

      refute Regex.match?(
               ~r/data-testid="perform-remove-btn"[^>]*disabled/,
               html
             )
    end

    @tag :unit
    test "move up button is disabled when nothing selected" do
      html = render_dialog(%{active_tab: "commands", perform_selected: nil})

      assert html =~ "perform-move-up-btn"

      assert Regex.match?(
               ~r/data-testid="perform-move-up-btn"[^>]*disabled/,
               html
             )
    end

    @tag :unit
    test "move up button is disabled when first entry is selected" do
      entries = [
        PerformEntry.new(command: "/join #a", position: 0),
        PerformEntry.new(command: "/join #b", position: 1)
      ]

      html =
        render_dialog(%{
          active_tab: "commands",
          perform_entries: entries,
          perform_selected: 0
        })

      assert Regex.match?(
               ~r/data-testid="perform-move-up-btn"[^>]*disabled/,
               html
             )
    end

    @tag :unit
    test "move up button is enabled when non-first entry is selected" do
      entries = [
        PerformEntry.new(command: "/join #a", position: 0),
        PerformEntry.new(command: "/join #b", position: 1)
      ]

      html =
        render_dialog(%{
          active_tab: "commands",
          perform_entries: entries,
          perform_selected: 1
        })

      refute Regex.match?(
               ~r/data-testid="perform-move-up-btn"[^>]*disabled/,
               html
             )
    end

    @tag :unit
    test "move down button is disabled when nothing selected" do
      html = render_dialog(%{active_tab: "commands", perform_selected: nil})

      assert html =~ "perform-move-down-btn"

      assert Regex.match?(
               ~r/data-testid="perform-move-down-btn"[^>]*disabled/,
               html
             )
    end

    @tag :unit
    test "move down button is disabled when last entry is selected" do
      entries = [
        PerformEntry.new(command: "/join #a", position: 0),
        PerformEntry.new(command: "/join #b", position: 1)
      ]

      html =
        render_dialog(%{
          active_tab: "commands",
          perform_entries: entries,
          perform_selected: 1
        })

      assert Regex.match?(
               ~r/data-testid="perform-move-down-btn"[^>]*disabled/,
               html
             )
    end

    @tag :unit
    test "move down button is enabled when non-last entry is selected" do
      entries = [
        PerformEntry.new(command: "/join #a", position: 0),
        PerformEntry.new(command: "/join #b", position: 1)
      ]

      html =
        render_dialog(%{
          active_tab: "commands",
          perform_entries: entries,
          perform_selected: 0
        })

      refute Regex.match?(
               ~r/data-testid="perform-move-down-btn"[^>]*disabled/,
               html
             )
    end
  end

  describe "commands tab - enable checkbox" do
    @tag :unit
    test "renders enable on connect checkbox" do
      html = render_dialog(%{active_tab: "commands"})

      assert html =~ "perform-enable-checkbox"
      assert html =~ "Enable on connect"
      assert html =~ "perform_toggle_enabled"
    end

    @tag :unit
    test "checkbox is checked when perform_enabled is true" do
      html = render_dialog(%{active_tab: "commands", perform_enabled: true})

      assert html =~ "checked"
    end

    @tag :unit
    test "checkbox is not checked when perform_enabled is false" do
      html = render_dialog(%{active_tab: "commands", perform_enabled: false})

      # The checkbox should not have checked attribute
      refute Regex.match?(
               ~r/data-testid="perform-enable-checkbox"[^>]*checked/,
               html
             )
    end
  end

  describe "autojoin tab - empty state" do
    @tag :unit
    test "shows empty message when no entries" do
      html = render_dialog(%{active_tab: "autojoin", autojoin_entries: []})

      assert html =~ "autojoin-empty"
      assert html =~ "No auto-join channels configured"
    end

    @tag :unit
    test "shows table headers" do
      html = render_dialog(%{active_tab: "autojoin"})

      assert html =~ "Channel"
      assert html =~ "Key"
    end
  end

  describe "autojoin tab - with entries" do
    @tag :unit
    test "renders autojoin entries with channel name" do
      entries = [
        AutoJoinEntry.new(channel_name: "#elixir", position: 0),
        AutoJoinEntry.new(channel_name: "#phoenix", position: 1)
      ]

      html = render_dialog(%{active_tab: "autojoin", autojoin_entries: entries})

      assert html =~ "autojoin-entry-#elixir"
      assert html =~ "autojoin-entry-#phoenix"
      assert html =~ "#elixir"
      assert html =~ "#phoenix"
      refute html =~ "autojoin-empty"
    end

    @tag :unit
    test "shows masked key when channel has a key" do
      entries = [
        AutoJoinEntry.new(channel_name: "#secret", channel_key: "mykey", position: 0)
      ]

      html = render_dialog(%{active_tab: "autojoin", autojoin_entries: entries})

      assert html =~ "****"
      refute html =~ "mykey"
    end

    @tag :unit
    test "shows empty key column when channel has no key" do
      entries = [
        AutoJoinEntry.new(channel_name: "#public", position: 0)
      ]

      html = render_dialog(%{active_tab: "autojoin", autojoin_entries: entries})

      assert html =~ "#public"
      refute html =~ "****"
    end

    @tag :unit
    test "selected entry has highlight style" do
      entries = [
        AutoJoinEntry.new(channel_name: "#elixir", position: 0)
      ]

      html =
        render_dialog(%{
          active_tab: "autojoin",
          autojoin_entries: entries,
          autojoin_selected: "#elixir"
        })

      assert html =~ "background: #000080"
    end

    @tag :unit
    test "entries have click event for selection" do
      entries = [
        AutoJoinEntry.new(channel_name: "#elixir", position: 0)
      ]

      html = render_dialog(%{active_tab: "autojoin", autojoin_entries: entries})

      assert html =~ "autojoin_select"
      assert html =~ ~s(phx-value-channel="#elixir")
    end
  end

  describe "autojoin tab - button states" do
    @tag :unit
    test "add button is always enabled" do
      html = render_dialog(%{active_tab: "autojoin", autojoin_selected: nil})

      assert html =~ "autojoin-add-btn"
      assert html =~ "autojoin_dialog_add"

      refute Regex.match?(
               ~r/data-testid="autojoin-add-btn"[^>]*disabled/,
               html
             )
    end

    @tag :unit
    test "edit button is disabled when nothing selected" do
      html = render_dialog(%{active_tab: "autojoin", autojoin_selected: nil})

      assert html =~ "autojoin-edit-btn"

      assert Regex.match?(
               ~r/data-testid="autojoin-edit-btn"[^>]*disabled/,
               html
             )
    end

    @tag :unit
    test "edit button is enabled when entry is selected" do
      entries = [AutoJoinEntry.new(channel_name: "#test", position: 0)]

      html =
        render_dialog(%{
          active_tab: "autojoin",
          autojoin_entries: entries,
          autojoin_selected: "#test"
        })

      refute Regex.match?(
               ~r/data-testid="autojoin-edit-btn"[^>]*disabled/,
               html
             )
    end

    @tag :unit
    test "remove button is disabled when nothing selected" do
      html = render_dialog(%{active_tab: "autojoin", autojoin_selected: nil})

      assert html =~ "autojoin-remove-btn"

      assert Regex.match?(
               ~r/data-testid="autojoin-remove-btn"[^>]*disabled/,
               html
             )
    end

    @tag :unit
    test "remove button is enabled when entry is selected" do
      entries = [AutoJoinEntry.new(channel_name: "#test", position: 0)]

      html =
        render_dialog(%{
          active_tab: "autojoin",
          autojoin_entries: entries,
          autojoin_selected: "#test"
        })

      refute Regex.match?(
               ~r/data-testid="autojoin-remove-btn"[^>]*disabled/,
               html
             )
    end
  end

  describe "perform add sub-dialog" do
    @tag :unit
    test "renders when show_perform_add_dialog is true" do
      html = render_dialog(%{show_perform_add_dialog: true})

      assert html =~ "perform-add-dialog"
      assert html =~ "Add Perform Command"
      assert html =~ "perform-command-input"
    end

    @tag :unit
    test "does not render when show_perform_add_dialog is false" do
      html = render_dialog(%{show_perform_add_dialog: false})

      refute html =~ "perform-add-dialog"
    end

    @tag :unit
    test "has form with submit event" do
      html = render_dialog(%{show_perform_add_dialog: true})

      assert html =~ "perform_dialog_add_confirm"
    end

    @tag :unit
    test "has OK and Cancel buttons" do
      html = render_dialog(%{show_perform_add_dialog: true})

      assert html =~ "perform-add-confirm"
      assert html =~ "perform-add-cancel"
      assert html =~ "close_perform_add_dialog"
    end

    @tag :unit
    test "has placeholder text" do
      html = render_dialog(%{show_perform_add_dialog: true})

      assert html =~ "/join #channel"
    end
  end

  describe "perform edit sub-dialog" do
    @tag :unit
    test "renders when show_perform_edit_dialog is true" do
      entries = [PerformEntry.new(command: "/join #test", position: 0)]

      html =
        render_dialog(%{
          show_perform_edit_dialog: true,
          perform_entries: entries,
          perform_selected: 0
        })

      assert html =~ "perform-edit-dialog"
      assert html =~ "Edit Perform Command"
      assert html =~ "perform-edit-input"
    end

    @tag :unit
    test "does not render when show_perform_edit_dialog is false" do
      html = render_dialog(%{show_perform_edit_dialog: false})

      refute html =~ "perform-edit-dialog"
    end

    @tag :unit
    test "pre-fills input with selected entry command" do
      entries = [PerformEntry.new(command: "/join #elixir", position: 0)]

      html =
        render_dialog(%{
          show_perform_edit_dialog: true,
          perform_entries: entries,
          perform_selected: 0
        })

      assert html =~ "/join #elixir"
    end

    @tag :unit
    test "shows empty value when selected entry not found" do
      html =
        render_dialog(%{
          show_perform_edit_dialog: true,
          perform_entries: [],
          perform_selected: 99
        })

      assert html =~ "perform-edit-dialog"
    end

    @tag :unit
    test "has OK and Cancel buttons" do
      entries = [PerformEntry.new(command: "/join #test", position: 0)]

      html =
        render_dialog(%{
          show_perform_edit_dialog: true,
          perform_entries: entries,
          perform_selected: 0
        })

      assert html =~ "perform-edit-confirm"
      assert html =~ "perform-edit-cancel"
      assert html =~ "close_perform_edit_dialog"
    end

    @tag :unit
    test "has form with submit event" do
      entries = [PerformEntry.new(command: "/join #test", position: 0)]

      html =
        render_dialog(%{
          show_perform_edit_dialog: true,
          perform_entries: entries,
          perform_selected: 0
        })

      assert html =~ "perform_dialog_edit_confirm"
    end
  end

  describe "autojoin add sub-dialog" do
    @tag :unit
    test "renders when show_autojoin_add_dialog is true" do
      html = render_dialog(%{show_autojoin_add_dialog: true})

      assert html =~ "autojoin-add-dialog"
      assert html =~ "Add Auto-Join Channel"
      assert html =~ "autojoin-channel-input"
      assert html =~ "autojoin-key-input"
    end

    @tag :unit
    test "does not render when show_autojoin_add_dialog is false" do
      html = render_dialog(%{show_autojoin_add_dialog: false})

      refute html =~ "autojoin-add-dialog"
    end

    @tag :unit
    test "has channel and key input fields" do
      html = render_dialog(%{show_autojoin_add_dialog: true})

      assert html =~ "Channel:"
      assert html =~ "Key (optional):"
      assert html =~ ~s(placeholder="#channel")
      assert html =~ "Leave empty if no key"
    end

    @tag :unit
    test "has OK and Cancel buttons" do
      html = render_dialog(%{show_autojoin_add_dialog: true})

      assert html =~ "autojoin-add-confirm"
      assert html =~ "autojoin-add-cancel"
      assert html =~ "close_autojoin_add_dialog"
    end

    @tag :unit
    test "has form with submit event" do
      html = render_dialog(%{show_autojoin_add_dialog: true})

      assert html =~ "autojoin_dialog_add_confirm"
    end
  end

  describe "autojoin edit sub-dialog" do
    @tag :unit
    test "renders when show_autojoin_edit_dialog is true" do
      entries = [AutoJoinEntry.new(channel_name: "#test", channel_key: "key1", position: 0)]

      html =
        render_dialog(%{
          show_autojoin_edit_dialog: true,
          autojoin_entries: entries,
          autojoin_selected: "#test"
        })

      assert html =~ "autojoin-edit-dialog"
      assert html =~ "Edit Auto-Join Channel"
      assert html =~ "autojoin-edit-channel"
      assert html =~ "autojoin-edit-key"
    end

    @tag :unit
    test "does not render when show_autojoin_edit_dialog is false" do
      html = render_dialog(%{show_autojoin_edit_dialog: false})

      refute html =~ "autojoin-edit-dialog"
    end

    @tag :unit
    test "pre-fills channel name (disabled) and key" do
      entries = [AutoJoinEntry.new(channel_name: "#elixir", channel_key: "secret", position: 0)]

      html =
        render_dialog(%{
          show_autojoin_edit_dialog: true,
          autojoin_entries: entries,
          autojoin_selected: "#elixir"
        })

      assert html =~ "#elixir"
      assert html =~ "secret"
      # Channel field should be disabled in edit mode
      assert Regex.match?(
               ~r/data-testid="autojoin-edit-channel"[^>]*disabled/,
               html
             )
    end

    @tag :unit
    test "shows empty values when selected entry not found" do
      html =
        render_dialog(%{
          show_autojoin_edit_dialog: true,
          autojoin_entries: [],
          autojoin_selected: "#nonexistent"
        })

      assert html =~ "autojoin-edit-dialog"
    end

    @tag :unit
    test "pre-fills empty key when entry has no key" do
      entries = [AutoJoinEntry.new(channel_name: "#public", position: 0)]

      html =
        render_dialog(%{
          show_autojoin_edit_dialog: true,
          autojoin_entries: entries,
          autojoin_selected: "#public"
        })

      assert html =~ "#public"
      # Key input should have empty value
      assert html =~ "autojoin-edit-key"
    end

    @tag :unit
    test "has OK and Cancel buttons" do
      entries = [AutoJoinEntry.new(channel_name: "#test", position: 0)]

      html =
        render_dialog(%{
          show_autojoin_edit_dialog: true,
          autojoin_entries: entries,
          autojoin_selected: "#test"
        })

      assert html =~ "autojoin-edit-confirm"
      assert html =~ "autojoin-edit-cancel"
      assert html =~ "close_autojoin_edit_dialog"
    end

    @tag :unit
    test "has form with submit event" do
      entries = [AutoJoinEntry.new(channel_name: "#test", position: 0)]

      html =
        render_dialog(%{
          show_autojoin_edit_dialog: true,
          autojoin_entries: entries,
          autojoin_selected: "#test"
        })

      assert html =~ "autojoin_dialog_edit_confirm"
    end
  end

  describe "multiple sub-dialogs" do
    @tag :unit
    test "sub-dialogs render outside main dialog (visible=false hides main but not sub)" do
      html =
        render_dialog(%{
          visible: false,
          show_perform_add_dialog: true
        })

      # Main dialog hidden
      refute html =~ "Perform / Auto-Commands"
      # Sub-dialog still renders (it uses :if independently)
      assert html =~ "perform-add-dialog"
    end

    @tag :unit
    test "multiple entries display in order" do
      entries = [
        PerformEntry.new(command: "/join #first", position: 0),
        PerformEntry.new(command: "/join #second", position: 1),
        PerformEntry.new(command: "/join #third", position: 2)
      ]

      html = render_dialog(%{active_tab: "commands", perform_entries: entries})

      assert html =~ "perform-entry-0"
      assert html =~ "perform-entry-1"
      assert html =~ "perform-entry-2"
      assert html =~ "/join #first"
      assert html =~ "/join #second"
      assert html =~ "/join #third"
    end

    @tag :unit
    test "multiple autojoin entries display" do
      entries = [
        AutoJoinEntry.new(channel_name: "#alpha", position: 0),
        AutoJoinEntry.new(channel_name: "#beta", channel_key: "pass", position: 1),
        AutoJoinEntry.new(channel_name: "#gamma", position: 2)
      ]

      html = render_dialog(%{active_tab: "autojoin", autojoin_entries: entries})

      assert html =~ "#alpha"
      assert html =~ "#beta"
      assert html =~ "#gamma"
      # Only #beta has a key, so only one "****"
      assert Regex.scan(~r/\*\*\*\*/, html) |> length() == 1
    end
  end
end
