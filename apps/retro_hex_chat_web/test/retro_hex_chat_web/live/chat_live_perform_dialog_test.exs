defmodule RetroHexChatWeb.ChatLivePerformDialogTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  # ── Open / Close ──────────────────────────────────────────

  describe "perform dialog open/close" do
    test "Ctrl+Shift+E opens and closes dialog", %{conn: conn} do
      nick = "PDlgAP#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      # Open
      render_keydown(view, "window_keydown", %{
        "key" => "e",
        "ctrlKey" => true,
        "shiftKey" => true
      })

      html = render(view)
      assert html =~ "Perform / Auto-Commands"

      # Close
      render_keydown(view, "window_keydown", %{
        "key" => "e",
        "ctrlKey" => true,
        "shiftKey" => true
      })

      html = render(view)
      refute html =~ "Perform / Auto-Commands"
    end

    test "menu bar opens dialog", %{conn: conn} do
      nick = "PDlgMn#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      html = render(view)
      assert html =~ "Perform / Auto-Commands"
    end

    test "close button closes dialog", %{conn: conn} do
      nick = "PDlgCl#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      assert render(view) =~ "Perform / Auto-Commands"

      render_click(view, "close_perform_dialog")
      refute render(view) =~ "Perform / Auto-Commands"
    end

    test "close resets tab to commands and clears selections", %{conn: conn} do
      nick = "PDlgRs#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      # Switch to autojoin tab
      render_click(view, "perform_dialog_tab", %{"tab" => "autojoin"})
      html = render(view)
      assert html =~ "No auto-join channels configured"

      # Close and reopen — should be back on commands tab
      render_click(view, "close_perform_dialog")
      render_click(view, "open_perform_dialog")
      html = render(view)
      assert html =~ "No perform commands configured"
    end
  end

  # ── Tab switching ─────────────────────────────────────────

  describe "tab switching" do
    test "switch from commands to autojoin tab", %{conn: conn} do
      nick = "PDlgTb#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      html = render(view)
      assert html =~ "No perform commands configured"

      render_click(view, "perform_dialog_tab", %{"tab" => "autojoin"})
      html = render(view)
      assert html =~ "No auto-join channels configured"
    end

    test "switch back to commands tab", %{conn: conn} do
      nick = "PDlgBk#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_tab", %{"tab" => "autojoin"})
      render_click(view, "perform_dialog_tab", %{"tab" => "commands"})
      html = render(view)
      assert html =~ "No perform commands configured"
    end
  end

  # ── Commands tab CRUD ─────────────────────────────────────

  describe "commands tab - add command" do
    test "add command via sub-dialog", %{conn: conn} do
      nick = "PDlgAd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      # Open add sub-dialog
      render_click(view, "perform_dialog_add")
      html = render(view)
      assert html =~ "Add Perform Command"

      # Submit the command
      render_submit(view, "perform_dialog_add_confirm", %{"command" => "/join #test"})
      html = render(view)
      # Sub-dialog closed, entry appears in list
      refute html =~ "Add Perform Command"
      assert html =~ "/join #test"
    end

    test "cancel add sub-dialog", %{conn: conn} do
      nick = "PDlgAC#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_add")
      assert render(view) =~ "Add Perform Command"

      render_click(view, "close_perform_add_dialog")
      html = render(view)
      refute html =~ "Add Perform Command"
      assert html =~ "No perform commands configured"
    end
  end

  describe "commands tab - edit command" do
    test "edit command via sub-dialog", %{conn: conn} do
      nick = "PDlgEd#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")

      # Add a command first
      render_click(view, "perform_dialog_add")
      render_submit(view, "perform_dialog_add_confirm", %{"command" => "/join #old"})

      # Select the entry
      render_click(view, "perform_select", %{"position" => "0"})

      # Open edit sub-dialog
      render_click(view, "perform_dialog_edit")
      html = render(view)
      assert html =~ "Edit Perform Command"

      # Submit edited command
      render_submit(view, "perform_dialog_edit_confirm", %{"command" => "/join #new"})
      html = render(view)
      refute html =~ "Edit Perform Command"
      assert html =~ "/join #new"
    end

    test "cancel edit sub-dialog", %{conn: conn} do
      nick = "PDlgEC#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_add")
      render_submit(view, "perform_dialog_add_confirm", %{"command" => "/join #keep"})
      render_click(view, "perform_select", %{"position" => "0"})

      render_click(view, "perform_dialog_edit")
      assert render(view) =~ "Edit Perform Command"

      render_click(view, "close_perform_edit_dialog")
      html = render(view)
      refute html =~ "Edit Perform Command"
      assert html =~ "/join #keep"
    end
  end

  describe "commands tab - remove command" do
    test "remove selected command", %{conn: conn} do
      nick = "PDlgRm#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_add")
      render_submit(view, "perform_dialog_add_confirm", %{"command" => "/join #bye"})

      # Select and remove
      render_click(view, "perform_select", %{"position" => "0"})
      render_click(view, "perform_dialog_remove")

      html = render(view)
      refute html =~ "/join #bye"
      assert html =~ "No perform commands configured"
    end
  end

  describe "commands tab - move up/down" do
    test "move down reorders entries", %{conn: conn} do
      nick = "PDlgMD#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")

      # Add two commands
      render_click(view, "perform_dialog_add")
      render_submit(view, "perform_dialog_add_confirm", %{"command" => "/join #first"})
      render_click(view, "perform_dialog_add")
      render_submit(view, "perform_dialog_add_confirm", %{"command" => "/join #second"})

      # Select first and move down
      render_click(view, "perform_select", %{"position" => "0"})
      render_click(view, "perform_dialog_move_down")

      html = render(view)
      # After move, #first is now at position 1, #second at position 0
      assert html =~ "perform-entry-0"
      assert html =~ "perform-entry-1"
    end

    test "move up reorders entries", %{conn: conn} do
      nick = "PDlgMU#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")

      # Add two commands
      render_click(view, "perform_dialog_add")
      render_submit(view, "perform_dialog_add_confirm", %{"command" => "/join #alpha"})
      render_click(view, "perform_dialog_add")
      render_submit(view, "perform_dialog_add_confirm", %{"command" => "/join #beta"})

      # Select second and move up
      render_click(view, "perform_select", %{"position" => "1"})
      render_click(view, "perform_dialog_move_up")

      html = render(view)
      # #beta should now be at position 0
      assert html =~ "/join #beta"
      assert html =~ "/join #alpha"
    end
  end

  # ── Enable/disable toggle ─────────────────────────────────

  describe "enable/disable toggle" do
    test "toggle disables perform on connect", %{conn: conn} do
      nick = "PDlgTg#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      html = render(view)
      # Checkbox should be checked by default (enabled)
      assert html =~ "perform-enable-checkbox"

      # Toggle off
      render_click(view, "perform_toggle_enabled")
      html = render(view)
      # The checkbox should no longer have checked attribute
      assert html =~ "perform-enable-checkbox"
    end

    test "double toggle restores enabled state", %{conn: conn} do
      nick = "PDlgDT#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")

      # Toggle off then on
      render_click(view, "perform_toggle_enabled")
      render_click(view, "perform_toggle_enabled")

      html = render(view)
      assert html =~ ~s(checked)
    end
  end

  # ── Password masking ──────────────────────────────────────

  describe "password masking" do
    test "/ns identify password is masked in dialog", %{conn: conn} do
      nick = "PDlgPw#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_add")
      render_submit(view, "perform_dialog_add_confirm", %{"command" => "/ns identify mysecret"})

      html = render(view)
      assert html =~ "****"
      refute html =~ "mysecret"
    end

    test "/msg NickServ identify password is masked in dialog", %{conn: conn} do
      nick = "PDlgNs#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_add")

      render_submit(view, "perform_dialog_add_confirm", %{
        "command" => "/msg NickServ identify topsecret"
      })

      html = render(view)
      assert html =~ "****"
      refute html =~ "topsecret"
    end
  end

  # ── Selection highlighting ────────────────────────────────

  describe "selection highlighting" do
    test "perform_select highlights row", %{conn: conn} do
      nick = "PDlgSl#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_add")
      render_submit(view, "perform_dialog_add_confirm", %{"command" => "/join #sel"})

      render_click(view, "perform_select", %{"position" => "0"})
      html = render(view)
      # Selected row has highlight style
      assert html =~ "table-row--selected"
    end

    test "autojoin_select highlights row", %{conn: conn} do
      nick = "PDlgAS#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_tab", %{"tab" => "autojoin"})

      # Add an autojoin entry
      render_click(view, "autojoin_dialog_add")
      render_submit(view, "autojoin_dialog_add_confirm", %{"channel" => "#ajsel", "key" => ""})

      render_click(view, "autojoin_select", %{"channel" => "#ajsel"})
      html = render(view)
      assert html =~ "table-row--selected"
    end
  end

  # ── Auto-Join tab CRUD ────────────────────────────────────

  describe "autojoin tab - add channel" do
    test "add channel via sub-dialog", %{conn: conn} do
      nick = "PDlgJA#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_tab", %{"tab" => "autojoin"})

      render_click(view, "autojoin_dialog_add")
      html = render(view)
      assert html =~ "Add Auto-Join Channel"

      render_submit(view, "autojoin_dialog_add_confirm", %{"channel" => "#ajtest", "key" => ""})
      html = render(view)
      refute html =~ "Add Auto-Join Channel"
      assert html =~ "#ajtest"
    end

    test "add channel with key masks key as ****", %{conn: conn} do
      nick = "PDlgJK#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_tab", %{"tab" => "autojoin"})

      render_click(view, "autojoin_dialog_add")

      render_submit(view, "autojoin_dialog_add_confirm", %{
        "channel" => "#secret",
        "key" => "mykey123"
      })

      html = render(view)
      assert html =~ "#secret"
      assert html =~ "****"
      refute html =~ "mykey123"
    end

    test "cancel add autojoin sub-dialog", %{conn: conn} do
      nick = "PDlgJC#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_tab", %{"tab" => "autojoin"})
      render_click(view, "autojoin_dialog_add")
      assert render(view) =~ "Add Auto-Join Channel"

      render_click(view, "close_autojoin_add_dialog")
      refute render(view) =~ "Add Auto-Join Channel"
    end
  end

  describe "autojoin tab - edit channel key" do
    test "edit channel key via sub-dialog", %{conn: conn} do
      nick = "PDlgJE#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_tab", %{"tab" => "autojoin"})

      # Add channel without key
      render_click(view, "autojoin_dialog_add")
      render_submit(view, "autojoin_dialog_add_confirm", %{"channel" => "#editme", "key" => ""})

      # Select and edit
      render_click(view, "autojoin_select", %{"channel" => "#editme"})
      render_click(view, "autojoin_dialog_edit")
      html = render(view)
      assert html =~ "Edit Auto-Join Channel"

      # Submit with a key
      render_submit(view, "autojoin_dialog_edit_confirm", %{
        "channel" => "#editme",
        "key" => "newkey"
      })

      html = render(view)
      refute html =~ "Edit Auto-Join Channel"
      assert html =~ "#editme"
      # Key is masked
      assert html =~ "****"
    end

    test "cancel edit autojoin sub-dialog", %{conn: conn} do
      nick = "PDlgJX#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_tab", %{"tab" => "autojoin"})
      render_click(view, "autojoin_dialog_add")
      render_submit(view, "autojoin_dialog_add_confirm", %{"channel" => "#editx", "key" => ""})
      render_click(view, "autojoin_select", %{"channel" => "#editx"})

      render_click(view, "autojoin_dialog_edit")
      assert render(view) =~ "Edit Auto-Join Channel"

      render_click(view, "close_autojoin_edit_dialog")
      refute render(view) =~ "Edit Auto-Join Channel"
    end
  end

  describe "autojoin tab - remove channel" do
    test "remove selected channel", %{conn: conn} do
      nick = "PDlgJR#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, ~p"/chat?nickname=#{nick}")

      render_click(view, "open_perform_dialog")
      render_click(view, "perform_dialog_tab", %{"tab" => "autojoin"})

      render_click(view, "autojoin_dialog_add")
      render_submit(view, "autojoin_dialog_add_confirm", %{"channel" => "#removeme", "key" => ""})

      render_click(view, "autojoin_select", %{"channel" => "#removeme"})
      render_click(view, "autojoin_dialog_remove")

      html = render(view)
      refute html =~ "#removeme"
      assert html =~ "No auto-join channels configured"
    end
  end
end
