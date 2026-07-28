defmodule RetroHexChatWeb.PaginatedListTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @moduletag :liveview

  alias RetroHexChat.Page
  alias RetroHexChatWeb.PaginatedListProbe

  defp rows(range), do: Enum.map(range, &%{id: &1, label: "row-#{&1}"})

  defp page(items, opts \\ []) do
    %Page{
      items: items,
      has_more: Keyword.get(opts, :has_more, false),
      next_cursor: Keyword.get(opts, :next_cursor)
    }
  end

  # `send_update/2` posts to `self()`, which from the test process would never
  # reach the LiveView. The pid-taking arity is the one that works from a test.
  defp send_action(view, action) do
    Phoenix.LiveView.send_update(view.pid, PaginatedListProbe.Island,
      id: "probe",
      action: action
    )

    render(view)
  end

  defp parent_assigns(view), do: :sys.get_state(view.pid).socket.assigns

  defp rendered_row_ids(html) do
    Regex.scan(~r/data-row="(\d+)"/, html) |> Enum.map(fn [_, id] -> String.to_integer(id) end)
  end

  describe "reset/4" do
    test "renders the page and adopts its pagination state", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, PaginatedListProbe)

      html = send_action(view, {:reset, page(rows(1..3), has_more: true, next_cursor: 3)})

      assert rendered_row_ids(html) == [1, 2, 3]
    end

    test "replaces previous rows rather than adding to them", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, PaginatedListProbe)

      send_action(view, {:reset, page(rows(1..3))})
      html = send_action(view, {:reset, page(rows(7..9))})

      assert rendered_row_ids(html) == [7, 8, 9]
    end
  end

  describe "append/3" do
    test "adds the page after the existing rows", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, PaginatedListProbe)

      send_action(view, {:reset, page(rows(1..3), has_more: true, next_cursor: 3)})
      html = send_action(view, {:append, page(rows(4..6))})

      assert rendered_row_ids(html) == [1, 2, 3, 4, 5, 6]
    end
  end

  describe "prepend/3" do
    test "adds the page above the existing rows, in order", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, PaginatedListProbe)

      send_action(view, {:reset, page(rows(4..6), has_more: true, next_cursor: 4)})
      html = send_action(view, {:prepend, page(rows(1..3))})

      assert rendered_row_ids(html) == [1, 2, 3, 4, 5, 6]
    end
  end

  describe "the DOM cap" do
    test "keeps only three pages of rows however far the reader scrolls", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, PaginatedListProbe)

      # page_size is 3 in the probe, so the cap is 9 rows.
      send_action(view, {:reset, page(rows(1..3), has_more: true, next_cursor: 3)})

      html =
        Enum.reduce(1..4, nil, fn n, _acc ->
          first = n * 3 + 1
          send_action(view, {:append, page(rows(first..(first + 2)))})
        end)

      ids = rendered_row_ids(html)

      assert length(ids) == 9, "expected the stream cap to hold the DOM at three pages"
      assert List.last(ids) == 15
    end
  end

  describe "load/3" do
    test "fetches with the cursor the last page handed back", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, PaginatedListProbe)
      test_pid = self()

      send_action(view, {:reset, page(rows(1..3), has_more: true, next_cursor: 3)})

      fetch = fn opts ->
        send(test_pid, {:fetched, opts})
        page(rows(4..6))
      end

      send_action(view, {:load, fetch})

      assert_receive {:fetched, opts}
      assert opts[:cursor] == 3
      assert opts[:limit] == 3
    end

    test "does not fetch when the list is exhausted", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, PaginatedListProbe)
      test_pid = self()

      send_action(view, {:reset, page(rows(1..3), has_more: false)})

      fetch = fn opts ->
        send(test_pid, {:fetched, opts})
        Page.empty()
      end

      send_action(view, {:load, fetch})

      refute_receive {:fetched, _opts}
    end

    test "does not fetch while a request is already in flight", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, PaginatedListProbe)
      test_pid = self()

      send_action(view, {:reset, page(rows(1..3), has_more: true, next_cursor: 3)})
      send_action(view, :loading)

      fetch = fn opts ->
        send(test_pid, {:fetched, opts})
        Page.empty()
      end

      send_action(view, {:load, fetch})

      refute_receive {:fetched, _opts}
    end

    test "a fetched last page stops any further fetching", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, PaginatedListProbe)
      test_pid = self()

      send_action(view, {:reset, page(rows(1..3), has_more: true, next_cursor: 3)})

      send_action(view, {:load, fn _opts -> page(rows(4..6), has_more: false) end})

      send_action(
        view,
        {:load,
         fn opts ->
           send(test_pid, {:fetched, opts})
           Page.empty()
         end}
      )

      refute_receive {:fetched, _opts}
    end
  end

  # Letting the fetch raise tears the LiveView down and rebuilds it showing the
  # first page, which reads to the reader as "there was nothing more" — the one
  # conclusion a failure must never produce.
  describe "a page that fails to load" do
    test "leaves the rows on screen and records the failure", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, PaginatedListProbe)

      send_action(view, {:reset, page(rows(1..3), has_more: true, next_cursor: 3)})

      html =
        send_action(view, {:load, fn _opts -> raise "the database went away" end})

      assert rendered_row_ids(html) == [1, 2, 3], "the rows already read must survive"
    end

    test "keeps the cursor, so retrying asks for the same page again", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, PaginatedListProbe)
      test_pid = self()

      send_action(view, {:reset, page(rows(1..3), has_more: true, next_cursor: 3)})
      send_action(view, {:load, fn _opts -> raise "transient" end})

      send_action(
        view,
        {:load,
         fn opts ->
           send(test_pid, {:retried, opts})
           page(rows(4..6))
         end}
      )

      assert_receive {:retried, opts}
      assert opts[:cursor] == 3
    end
  end

  describe "isolation from the parent" do
    test "pagination state lives in the island, not the parent LiveView", %{conn: conn} do
      {:ok, view, _html} = live_isolated(conn, PaginatedListProbe)

      send_action(view, {:reset, page(rows(1..3), has_more: true, next_cursor: 3)})

      refute Map.has_key?(parent_assigns(view), :paginated),
             "the parent must not carry the island's pagination state"
    end
  end
end
