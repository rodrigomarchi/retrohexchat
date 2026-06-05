defmodule RetroHexChatWeb.TimersDialogFeatureTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Chat.HelpTopics

  alias RetroHexChatWeb.Components.UI.{
    MenuBarApp,
    TimersDialog,
    ToolbarApp
  }

  setup do
    ensure_channel("#lobby")
    :ok
  end

  describe "timer entry points" do
    test "Tools menu and Options dropdown expose Timers after Auto Respond" do
      menu_html =
        render_component(&MenuBarApp.menu_bar_app/1,
          connected: true,
          on_action: "toolbar_action"
        )

      toolbar_html =
        render_component(&ToolbarApp.toolbar_app/1,
          connected: true,
          on_action: "toolbar_action"
        )

      assert menu_html =~ ~s(data-testid="context-menu-item-open_timers_dialog")
      assert toolbar_html =~ ~s(data-testid="context-menu-item-open_timers_dialog")
      assert menu_html =~ "Timers"
      assert toolbar_html =~ "Timers"

      assert action_before?(menu_html, "open_autorespond_dialog", "open_timers_dialog")
      assert action_before?(toolbar_html, "open_autorespond_dialog", "open_timers_dialog")
    end

    test "bare /timer opens the Timers dialog", %{conn: conn} do
      view = connect_user(conn, "TimerOpen#{uid()}")

      refute has_element?(view, "#timers-dialog-show-trigger")

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/timer"})

      assert has_element?(view, "#timers-dialog-show-trigger")
      assert render(view) =~ "No active timers. Click Add to schedule one."
    end
  end

  describe "Timers dialog component" do
    test "renders empty, row, repeat warning, and max-limit states" do
      assert render_timers_dialog(%{timers: %{}}) =~
               "No active timers. Click Add to schedule one."

      assert render_timers_dialog(%{timers: %{}}) =~
               "Timers are session-only and will be lost on disconnect."

      ref = Process.send_after(self(), :timer_dialog_test_noop, 60_000)
      on_exit(fn -> Process.cancel_timer(ref) end)

      row_html =
        render_timers_dialog(%{
          timers: %{
            "heartbeat" => %{
              type: :repeat,
              interval: 600,
              command: "/me is still here",
              ref: ref
            }
          },
          selected_timer: "heartbeat",
          editing: true,
          draft_name: "heartbeat",
          draft_repeat: true,
          draft_seconds: "5",
          draft_command: "/me is still here"
        })

      assert row_html =~ ~s(data-testid="timer-row-heartbeat")
      assert row_html =~ "heartbeat"
      assert row_html =~ "600s"
      assert row_html =~ "yes"
      assert row_html =~ "/me is still here"
      assert row_html =~ ~s(data-testid="timer-name-input")
      assert row_html =~ "min 10s for repeating timers"

      max_timers =
        for index <- 1..5, into: %{} do
          {"t#{index}", %{type: :once, interval: index, command: "/me #{index}"}}
        end

      max_html = render_timers_dialog(%{timers: max_timers})

      assert max_html =~ "Maximum 5 timers active. Stop one to add another."

      max_html
      |> Floki.parse_document!()
      |> Floki.find(~s([data-testid="timers-dialog-add"][disabled]))
      |> assert_non_empty()
    end
  end

  describe "timer CRUD flow" do
    test "Add, edit, repeat validation, and Stop map to live timer actions", %{conn: conn} do
      view = connect_user(conn, "TimerCrud#{uid()}")

      render_click(view, "toolbar_action", %{"action" => "open_timers_dialog"})
      render_click(view, "timers_dialog_add")

      invalid_html =
        view
        |> element("form[phx-submit=timers_dialog_save]")
        |> render_submit(%{
          "name" => "too_fast",
          "repeat" => "true",
          "seconds" => "5",
          "command" => "/me too fast"
        })

      assert invalid_html =~ "min 10s for repeating timers"
      refute invalid_html =~ ~s(data-testid="timer-row-too_fast")

      html =
        view
        |> element("form[phx-submit=timers_dialog_save]")
        |> render_submit(%{
          "name" => "remind",
          "seconds" => "15",
          "command" => "/me standup in 15 seconds"
        })

      assert html =~ ~s(data-testid="timer-row-remind")
      assert html =~ "15s"
      assert html =~ "no"
      assert html =~ "/me standup in 15 seconds"

      render_click(view, "timers_select", %{"name" => "remind"})
      render_click(view, "timers_dialog_edit")

      html =
        view
        |> element("form[phx-submit=timers_dialog_save]")
        |> render_submit(%{
          "name" => "remind",
          "seconds" => "20",
          "command" => "/me updated"
        })

      assert html =~ ~s(data-testid="timer-row-remind")
      assert html =~ "20s"
      assert html =~ "/me updated"

      render_click(view, "timers_select", %{"name" => "remind"})
      html = render_click(view, "timers_dialog_stop")

      refute html =~ ~s(data-testid="timer-row-remind")
      assert html =~ "No active timers. Click Add to schedule one."
    end
  end

  describe "help documentation" do
    test "timer topics expose dialog discovery and scripting cross references" do
      cmd = HelpTopics.get_topic("cmd-timer")
      feature = HelpTopics.get_topic("feature-timers")
      aliases = HelpTopics.get_topic("feature-aliases")
      autorespond = HelpTopics.get_topic("feature-autorespond")

      assert cmd != nil
      assert feature != nil
      assert aliases != nil
      assert autorespond != nil

      assert "timers dialog" in cmd.keywords
      assert "open_timers_dialog" in cmd.keywords
      assert "toolbar options" in feature.keywords
      assert "timers dialog" in aliases.keywords
      assert "timers" in autorespond.keywords
    end
  end

  defp render_timers_dialog(overrides) do
    defaults = %{
      id: "timers-dialog",
      show: true,
      timers: %{},
      selected_timer: nil,
      editing: false,
      draft_name: "",
      draft_repeat: false,
      draft_seconds: "",
      draft_command: "",
      error_message: nil,
      on_select: "timers_select",
      on_add: "timers_dialog_add",
      on_edit: "timers_dialog_edit",
      on_stop: "timers_dialog_stop",
      on_change: "timers_dialog_change",
      on_save: "timers_dialog_save",
      on_cancel_edit: "timers_dialog_cancel_edit",
      on_close: "close_timers_dialog"
    }

    render_component(&TimersDialog.timers_dialog/1, Map.merge(defaults, overrides))
  end

  defp action_before?(html, before_action, after_action) do
    actions =
      html
      |> Floki.parse_document!()
      |> Floki.find("[data-testid^=\"context-menu-item-\"]")
      |> Enum.map(fn node ->
        node
        |> Floki.attribute("data-testid")
        |> List.first()
        |> String.replace_prefix("context-menu-item-", "")
      end)

    Enum.find_index(actions, &(&1 == before_action)) <
      Enum.find_index(actions, &(&1 == after_action))
  end

  defp assert_non_empty([_ | _]), do: :ok

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
