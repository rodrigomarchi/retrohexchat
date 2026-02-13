defmodule RetroHexChatWeb.Components.ChannelCentralDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  @moduletag :unit

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.ChannelCentralDialog

  @base_state %{
    name: "#test-cc",
    topic: "Test topic",
    topic_set_by: "founder",
    topic_set_at: ~U[2026-02-11 12:00:00Z],
    members: [{"founder", :owner}, {"user1", :regular}],
    member_count: 2,
    owners: ["founder"],
    operators: [],
    modes: "+t",
    modes_detail: %{
      moderated: false,
      invite_only: false,
      topic_lock: true,
      key: nil,
      limit: nil,
      no_external: false,
      secret: false,
      private: false,
      strip_colors: false,
      registered_only: false,
      no_knock: false,
      join_throttle: nil
    },
    bans: ["troll1", "troll2"],
    ban_exceptions: ["exempt1"],
    invite_exceptions: ["invited1"],
    created_at: ~U[2026-02-10 10:00:00Z]
  }

  defp render_dialog(attrs) do
    assigns =
      Map.merge(
        %{
          visible: true,
          active_tab: "general",
          channel_state: @base_state,
          operator: false,
          ban_selected: nil,
          ban_ex_selected: nil,
          invite_ex_selected: nil,
          modes_form: %{},
          show_add_ban_dialog: false,
          show_add_ban_ex_dialog: false,
          show_add_invite_ex_dialog: false
        },
        attrs
      )

    rendered =
      render_component(&ChannelCentralDialog.channel_central_dialog/1, assigns)

    rendered
  end

  describe "dialog visibility" do
    test "renders when visible=true and channel_state present" do
      html = render_dialog(%{})
      assert html =~ "channel-central-dialog"
      assert html =~ "Channel Central"
    end

    test "does not render when visible=false" do
      html = render_dialog(%{visible: false})
      refute html =~ "channel-central-dialog"
    end

    test "does not render when channel_state is nil" do
      html = render_dialog(%{channel_state: nil})
      refute html =~ "channel-central-dialog"
    end
  end

  describe "tab navigation" do
    test "renders all 5 tab labels" do
      html = render_dialog(%{})
      assert html =~ "cc-tab-general"
      assert html =~ "cc-tab-modes"
      assert html =~ "cc-tab-bans"
      assert html =~ "cc-tab-ban-ex"
      assert html =~ "cc-tab-invite-ex"
    end

    test "general tab is active by default" do
      html = render_dialog(%{active_tab: "general"})
      assert html =~ "cc-general-panel"
    end

    test "modes tab renders when active" do
      html = render_dialog(%{active_tab: "modes"})
      assert html =~ "cc-modes-panel"
    end

    test "bans tab renders when active" do
      html = render_dialog(%{active_tab: "bans"})
      assert html =~ "cc-bans-panel"
    end

    test "ban exceptions tab renders when active" do
      html = render_dialog(%{active_tab: "ban_exceptions"})
      assert html =~ "cc-ban-ex-panel"
    end

    test "invite exceptions tab renders when active" do
      html = render_dialog(%{active_tab: "invite_exceptions"})
      assert html =~ "cc-invite-ex-panel"
    end
  end

  describe "general tab" do
    test "displays channel info" do
      html = render_dialog(%{active_tab: "general"})
      assert html =~ "#test-cc"
      assert html =~ "2"
    end

    test "displays topic text" do
      html = render_dialog(%{active_tab: "general"})
      assert html =~ "Test topic"
    end

    test "displays topic metadata" do
      html = render_dialog(%{active_tab: "general"})
      assert html =~ "Set by founder"
    end

    test "non-operator sees read-only topic" do
      html = render_dialog(%{active_tab: "general", operator: false})
      refute html =~ "cc-set-topic-btn"
      refute html =~ "cc-topic-input"
    end

    test "operator sees editable topic with Set Topic button" do
      html = render_dialog(%{active_tab: "general", operator: true})
      assert html =~ "cc-set-topic-btn"
      assert html =~ "cc-topic-input"
    end

    test "shows 'No topic set' when topic is empty" do
      state = %{@base_state | topic: "", topic_set_by: nil, topic_set_at: nil}
      html = render_dialog(%{active_tab: "general", channel_state: state, operator: false})
      assert html =~ "No topic set"
    end
  end

  describe "modes tab" do
    test "non-operator sees disabled checkboxes" do
      html = render_dialog(%{active_tab: "modes", operator: false})
      assert html =~ "disabled"
      assert html =~ "Moderated (+m)"
      assert html =~ "Topic Lock (+t)"
      refute html =~ "cc-apply-modes-btn"
    end

    test "operator sees enabled checkboxes and Apply button" do
      html = render_dialog(%{active_tab: "modes", operator: true})
      assert html =~ "cc-apply-modes-btn"
      assert html =~ "Moderated (+m)"
    end

    test "reflects current mode state" do
      html = render_dialog(%{active_tab: "modes", operator: false})
      # topic_lock is true in @base_state.modes_detail
      assert html =~ "Topic Lock (+t)"
    end
  end

  describe "bans tab" do
    test "displays ban list" do
      html = render_dialog(%{active_tab: "bans"})
      assert html =~ "cc-ban-entry-troll1"
      assert html =~ "cc-ban-entry-troll2"
    end

    test "non-operator sees no Add/Remove buttons" do
      html = render_dialog(%{active_tab: "bans", operator: false})
      refute html =~ "cc-add-ban-btn"
      refute html =~ "cc-remove-ban-btn"
    end

    test "operator sees Add/Remove buttons" do
      html = render_dialog(%{active_tab: "bans", operator: true})
      assert html =~ "cc-add-ban-btn"
      assert html =~ "cc-remove-ban-btn"
    end

    test "shows 'No bans' when ban list is empty" do
      state = %{@base_state | bans: []}
      html = render_dialog(%{active_tab: "bans", channel_state: state})
      assert html =~ "No bans"
    end
  end

  describe "ban exceptions tab" do
    test "displays exception list" do
      html = render_dialog(%{active_tab: "ban_exceptions"})
      assert html =~ "cc-ban-ex-entry-exempt1"
    end

    test "non-operator sees no Add/Remove buttons" do
      html = render_dialog(%{active_tab: "ban_exceptions", operator: false})
      refute html =~ "cc-add-ban-ex-btn"
      refute html =~ "cc-remove-ban-ex-btn"
    end

    test "operator sees Add/Remove buttons" do
      html = render_dialog(%{active_tab: "ban_exceptions", operator: true})
      assert html =~ "cc-add-ban-ex-btn"
      assert html =~ "cc-remove-ban-ex-btn"
    end

    test "shows 'No ban exceptions' when list is empty" do
      state = %{@base_state | ban_exceptions: []}
      html = render_dialog(%{active_tab: "ban_exceptions", channel_state: state})
      assert html =~ "No ban exceptions"
    end
  end

  describe "invite exceptions tab" do
    test "displays exception list" do
      html = render_dialog(%{active_tab: "invite_exceptions"})
      assert html =~ "cc-invite-ex-entry-invited1"
    end

    test "non-operator sees no Add/Remove buttons" do
      html = render_dialog(%{active_tab: "invite_exceptions", operator: false})
      refute html =~ "cc-add-invite-ex-btn"
      refute html =~ "cc-remove-invite-ex-btn"
    end

    test "operator sees Add/Remove buttons" do
      html = render_dialog(%{active_tab: "invite_exceptions", operator: true})
      assert html =~ "cc-add-invite-ex-btn"
      assert html =~ "cc-remove-invite-ex-btn"
    end

    test "shows 'No invite exceptions' when list is empty" do
      state = %{@base_state | invite_exceptions: []}
      html = render_dialog(%{active_tab: "invite_exceptions", channel_state: state})
      assert html =~ "No invite exceptions"
    end
  end

  describe "sub-dialogs" do
    test "add ban dialog renders when show_add_ban_dialog is true" do
      html = render_dialog(%{active_tab: "bans", operator: true, show_add_ban_dialog: true})
      assert html =~ "cc-add-ban-dialog"
      assert html =~ "cc-ban-nick-input"
    end

    test "add ban exception dialog renders when shown" do
      html =
        render_dialog(%{
          active_tab: "ban_exceptions",
          operator: true,
          show_add_ban_ex_dialog: true
        })

      assert html =~ "cc-add-ban-ex-dialog"
      assert html =~ "cc-ban-ex-nick-input"
    end

    test "add invite exception dialog renders when shown" do
      html =
        render_dialog(%{
          active_tab: "invite_exceptions",
          operator: true,
          show_add_invite_ex_dialog: true
        })

      assert html =~ "cc-add-invite-ex-dialog"
      assert html =~ "cc-invite-ex-nick-input"
    end
  end

  describe "row selection highlighting" do
    test "selected ban row has highlight style" do
      html = render_dialog(%{active_tab: "bans", ban_selected: "troll1"})
      assert html =~ "background: #000080"
    end

    test "selected ban exception row has highlight style" do
      html = render_dialog(%{active_tab: "ban_exceptions", ban_ex_selected: "exempt1"})
      assert html =~ "background: #000080"
    end

    test "selected invite exception row has highlight style" do
      html = render_dialog(%{active_tab: "invite_exceptions", invite_ex_selected: "invited1"})
      assert html =~ "background: #000080"
    end
  end
end
