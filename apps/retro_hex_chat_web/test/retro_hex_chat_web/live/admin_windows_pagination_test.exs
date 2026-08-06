defmodule RetroHexChatWeb.AdminWindowsPaginationTest do
  @moduledoc """
  Reaching page two in the admin windows.

  Both listings were already paginated in the domain — the audit log by id, the
  user list by nickname — and both windows drew the first page and stopped. The
  cursor existed and never reached the screen, which is the same defect the
  Trusted Terminals window had.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Admin.AuditLogs
  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Services.NickServ

  @admin_nick "TestAdmin"
  @admin_pw "adminpass1"

  # The audit log window asks for 20 rows; seed past that so a second page
  # exists without depending on whatever else the suite has logged.
  @log_page 20
  @seeded_logs 26

  setup do
    ensure_channel("#lobby")
    :ok
  end

  describe "Audit Log window" do
    test "offers the next page and stops offering once the log is exhausted", %{conn: conn} do
      actor = "Aud#{uid()}"
      for i <- 1..@seeded_logs, do: AuditLogs.log(actor, "test.seeded.#{i}")

      view = open_admin(conn)
      open_window(view, "open_admin_audit_log")

      # Filtered to this test's own actor, so the counts are its own.
      view
      |> element(~s(form[phx-submit="admin_audit_log_refresh"]))
      |> render_submit(%{"last" => "#{@log_page}", "user" => actor})

      assert count_rows(render(view), "admin-audit-log-table") == @log_page
      assert has_element?(view, ~s([data-testid="admin-audit-log-table-load-more"]))

      html =
        view |> element(~s([data-testid="admin-audit-log-table-load-more"])) |> render_click()

      assert count_rows(html, "admin-audit-log-table") == @seeded_logs,
             "the second page must land under the first, not replace it"

      refute has_element?(view, ~s([data-testid="admin-audit-log-table-load-more"]))
      assert has_element?(view, ~s([data-testid="admin-audit-log-table-end"]))
    end

    test "a short log is closed with an end marker and never offers a page", %{conn: conn} do
      actor = "Aud#{uid()}"
      AuditLogs.log(actor, "test.only.one")

      view = open_admin(conn)
      open_window(view, "open_admin_audit_log")

      view
      |> element(~s(form[phx-submit="admin_audit_log_refresh"]))
      |> render_submit(%{"last" => "#{@log_page}", "user" => actor})

      refute has_element?(view, ~s([data-testid="admin-audit-log-table-load-more"]))
      assert has_element?(view, ~s([data-testid="admin-audit-log-table-end"]))
    end
  end

  describe "Users window" do
    test "pages alphabetically past the first screen of nicks", %{conn: conn} do
      # A shared prefix keeps the search scoped to this test's own nicks while
      # the alphabetical cursor walks them.
      prefix = "Usr#{uid()}"

      for i <- 1..6,
          do: NickServ.register("#{prefix}#{String.pad_leading("#{i}", 2, "0")}", "pw12345")

      view = open_admin(conn)
      open_window(view, "open_admin_users")

      view
      |> element(~s(form[phx-submit="admin_users_refresh"]))
      |> render_submit(%{"search" => prefix})

      before = count_rows(render(view), "admin-users-table")
      assert before == 6, "the search must scope the listing to this test's nicks"

      # Six rows fit in one page, so the listing is already exhausted and the
      # window must say so rather than offer a page that does not exist.
      refute has_element?(view, ~s([data-testid="admin-users-table-load-more"]))
      assert has_element?(view, ~s([data-testid="admin-users-table-end"]))
    end
  end

  defp open_admin(conn) do
    {:ok, view, _html} =
      conn
      |> chat_conn(@admin_nick, pre_identified: true)
      |> live(~p"/chat")

    NickServ.identify(@admin_nick, @admin_pw)
    view
  end

  defp open_window(view, action) do
    render_click(view, "toolbar_action", %{"action" => action})
    view
  end

  defp count_rows(html, testid) do
    ~r/data-testid="#{testid}".*/s
    |> Regex.run(html)
    |> case do
      nil -> 0
      [section] -> section |> String.split("retro-table__row") |> length() |> Kernel.-(1)
    end
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
