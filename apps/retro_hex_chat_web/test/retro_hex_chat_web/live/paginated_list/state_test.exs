defmodule RetroHexChatWeb.PaginatedList.StateTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Page
  alias RetroHexChatWeb.PaginatedList.State

  defp page(opts) do
    %Page{
      items: Keyword.get(opts, :items, []),
      has_more: Keyword.get(opts, :has_more, false),
      next_cursor: Keyword.get(opts, :next_cursor),
      total: Keyword.get(opts, :total)
    }
  end

  describe "new/1" do
    test "starts empty, not loading, with nothing known to follow" do
      state = State.new()

      assert state.cursor == nil
      assert state.has_more == false
      assert state.loading? == false
    end

    test "carries the page size it was configured with" do
      assert State.new(page_size: 25).page_size == 25
    end

    test "defaults the page size" do
      assert State.new().page_size == 50
    end
  end

  describe "dom_limit/1" do
    test "keeps three pages in the DOM" do
      # Enough above and below to read as an infinite list, small enough that
      # the browser stays fast — the ratio LiveView's own docs recommend.
      assert State.dom_limit(State.new(page_size: 50)) == 150
    end
  end

  describe "can_load_more?/1" do
    test "no when nothing follows" do
      refute State.can_load_more?(State.new())
    end

    test "yes when a page follows and nothing is in flight" do
      state = State.from_page(State.new(), page(has_more: true, next_cursor: 10))

      assert State.can_load_more?(state)
    end

    test "no while a request is in flight" do
      state =
        State.new()
        |> State.from_page(page(has_more: true, next_cursor: 10))
        |> State.loading()

      refute State.can_load_more?(state)
    end

    test "no when a page follows but there is no cursor to ask with" do
      # Defensive: has_more without a cursor is a contradiction, and asking the
      # server with a nil cursor would silently re-read the first page forever.
      state = State.from_page(State.new(), page(has_more: true, next_cursor: nil))

      refute State.can_load_more?(state)
    end
  end

  describe "loading/1" do
    test "marks a request in flight" do
      assert State.loading(State.new()).loading?
    end
  end

  describe "from_page/2" do
    test "adopts the cursor and has_more of the page, and clears loading" do
      state =
        State.new()
        |> State.loading()
        |> State.from_page(page(has_more: true, next_cursor: 42))

      assert state.cursor == 42
      assert state.has_more
      refute state.loading?
    end

    test "a last page clears both the cursor and has_more" do
      state =
        State.new()
        |> State.from_page(page(has_more: true, next_cursor: 42))
        |> State.from_page(page(has_more: false, next_cursor: nil))

      assert state.cursor == nil
      refute state.has_more
    end

    test "carries the total when the page has one" do
      state = State.from_page(State.new(), page(total: 5_000))

      assert state.total == 5_000
    end

    test "keeps the page size across pages" do
      state =
        State.new(page_size: 25)
        |> State.from_page(page(has_more: true, next_cursor: 1))

      assert state.page_size == 25
    end

    test "counts the rows every page brought" do
      state =
        State.new()
        |> State.from_page(page(items: [1, 2, 3], has_more: true, next_cursor: 3))
        |> State.from_page(page(items: [4, 5]))

      assert state.count == 5
    end
  end

  # A stream tells the markup nothing about how many rows it holds, so the state
  # is the only thing that can distinguish a list that is empty from one whose
  # rows simply have not been asked for yet — the difference between showing an
  # empty state and showing nothing at all.
  describe "counting rows" do
    test "a fresh list has counted nothing" do
      assert State.new().count == 0
    end

    test "empty?/1 is true only for a loaded list with no rows" do
      assert State.empty?(State.from_page(State.new(), page(items: [])))
      refute State.empty?(State.from_page(State.new(), page(items: [1])))
    end

    test "a list that has not loaded yet is not empty, it is unknown" do
      # Otherwise every paginated list would flash its empty state in the gap
      # between mounting and its first page landing.
      refute State.empty?(State.new())
      refute State.loaded?(State.new())
      assert State.loaded?(State.from_page(State.new(), page(items: [])))
    end

    test "exhausted?/1 is a list that has rows and nothing following them" do
      assert State.exhausted?(State.from_page(State.new(), page(items: [1])))

      refute State.exhausted?(
               State.from_page(State.new(), page(items: [1], has_more: true, next_cursor: 1))
             )

      refute State.exhausted?(State.from_page(State.new(), page(items: []))),
             "an empty list is empty, not exhausted — the two states must not both render"
    end

    test "reports a failed load, keeping the cursor so a retry asks for the same page" do
      # Clearing the cursor here would turn a failure into a silently shortened
      # list — the reader would conclude the list had ended.
      state =
        State.new()
        |> State.from_page(page(items: [1], has_more: true, next_cursor: 7))
        |> State.loading()
        |> State.failed()

      assert State.error?(state)
      refute State.loading?(state)
      assert state.cursor == 7
      assert State.can_load_more?(state), "a retry must be allowed"
    end

    test "a page that lands clears the error" do
      state =
        State.new()
        |> State.from_page(page(items: [1], has_more: true, next_cursor: 7))
        |> State.failed()
        |> State.from_page(page(items: [2]))

      refute State.error?(state)
    end

    test "every predicate is false without a state, so an unpaginated list stays plain" do
      # Presentational components take the state as an optional attribute; with
      # none they must render the rows and no pagination furniture at all.
      refute State.loaded?(nil)
      refute State.empty?(nil)
      refute State.exhausted?(nil)
      refute State.more?(nil)
      refute State.loading?(nil)
      refute State.error?(nil)
    end

    test "reset/1 forgets the rows it had counted, and that it ever loaded" do
      state =
        State.new()
        |> State.from_page(page(items: [1, 2, 3]))
        |> State.reset()

      assert state.count == 0
      refute State.loaded?(state)
    end
  end

  describe "reset/1" do
    test "returns to the initial state but keeps the configuration" do
      state =
        State.new(page_size: 25)
        |> State.from_page(page(has_more: true, next_cursor: 42, total: 100))
        |> State.loading()
        |> State.reset()

      assert state.cursor == nil
      assert state.total == nil
      refute state.has_more
      refute state.loading?
      assert state.page_size == 25
    end
  end

  describe "query_opts/1" do
    test "asks for the page size and the cursor it holds" do
      state = State.from_page(State.new(page_size: 25), page(has_more: true, next_cursor: 42))

      assert State.query_opts(state) == [limit: 25, cursor: 42]
    end

    test "omits the cursor on a first page" do
      assert State.query_opts(State.new(page_size: 25)) == [limit: 25]
    end
  end

  describe "hook_attrs/1" do
    test "hands the server's view of pagination to the hook as strings" do
      state = State.from_page(State.new(), page(has_more: true, next_cursor: 1))

      attrs = State.hook_attrs(state)

      assert attrs["data-has-more"] == "true"
      assert attrs["data-loading"] == "false"
    end

    test "tells the hook to stop asking once the list is exhausted" do
      attrs = State.hook_attrs(State.new())

      assert attrs["data-has-more"] == "false"
    end

    test "tells the hook a request is already in flight" do
      state =
        State.new()
        |> State.from_page(page(has_more: true, next_cursor: 1))
        |> State.loading()

      assert State.hook_attrs(state)["data-loading"] == "true"
    end
  end
end
