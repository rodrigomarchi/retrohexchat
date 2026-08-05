defmodule RetroHexChat.SystemInfo.QueryTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.SystemInfo.Query

  @columns [:name, :memory, :reductions]

  describe "new/2 — bounding what a parameter may become" do
    test "a known column name resolves to the atom the row map is keyed by" do
      assert %Query{sort_by: :memory} = Query.new(%{"sort_by" => "memory"}, @columns)
    end

    test "an unknown column is dropped rather than interned as an atom" do
      before = :erlang.system_info(:atom_count)

      assert %Query{sort_by: nil} = Query.new(%{"sort_by" => "definitely_not_a_column"}, @columns)

      assert :erlang.system_info(:atom_count) == before
    end

    test "a column belonging to a different source is refused" do
      assert %Query{sort_by: nil} = Query.new(%{"sort_by" => "protection"}, @columns)
    end

    test "blank and whitespace searches are no search at all" do
      assert %Query{search: nil} = Query.new(%{"search" => "   "}, @columns)
      assert %Query{search: nil} = Query.new(%{"search" => ""}, @columns)
      assert %Query{search: "gen"} = Query.new(%{"search" => "  gen  "}, @columns)
    end

    test "the limit is clamped rather than obeyed" do
      assert %Query{limit: 500} = Query.new(%{"limit" => "100000"}, @columns)
      assert %Query{limit: 50} = Query.new(%{"limit" => "0"}, @columns)
      assert %Query{limit: 50} = Query.new(%{"limit" => "not a number"}, @columns)
      assert %Query{limit: 25} = Query.new(%{"limit" => "25"}, @columns)
    end

    test "direction defaults to descending, because the interesting row is the biggest" do
      assert %Query{sort_dir: :desc} = Query.new(%{}, @columns)
      assert %Query{sort_dir: :asc} = Query.new(%{"sort_dir" => "asc"}, @columns)
    end
  end

  describe "toggle_sort/2" do
    test "clicking the sorted column flips direction" do
      query = %Query{sort_by: :memory, sort_dir: :desc}

      assert %Query{sort_by: :memory, sort_dir: :asc} = Query.toggle_sort(query, :memory)
    end

    test "clicking another column starts it descending" do
      query = %Query{sort_by: :memory, sort_dir: :asc}

      assert %Query{sort_by: :name, sort_dir: :desc} = Query.toggle_sort(query, :name)
    end
  end

  describe "matches?/2" do
    test "no term matches everything" do
      assert Query.matches?(nil, ["anything"])
    end

    test "matching ignores case and looks at every value offered" do
      assert Query.matches?("GEN", ["gen_server.loop/5", "#PID<0.1.0>"])
      assert Query.matches?("pid", ["gen_server.loop/5", "#PID<0.1.0>"])
      refute Query.matches?("absent", ["gen_server.loop/5", "#PID<0.1.0>"])
    end

    test "non-string values are matched by their printed form" do
      assert Query.matches?("42", [42])
    end
  end

  describe "paginate/2" do
    test "orders by the column and takes one page" do
      rows = [%{memory: 3}, %{memory: 1}, %{memory: 2}]
      query = %Query{sort_by: :memory, sort_dir: :desc, limit: 2}

      assert [%{memory: 3}, %{memory: 2}] = Query.paginate(query, rows)
    end

    test "ascending reverses the order" do
      rows = [%{memory: 3}, %{memory: 1}, %{memory: 2}]
      query = %Query{sort_by: :memory, sort_dir: :asc, limit: 3}

      assert [%{memory: 1}, %{memory: 2}, %{memory: 3}] = Query.paginate(query, rows)
    end

    test "a missing value sorts as zero rather than raising" do
      rows = [%{memory: 5}, %{other: :key}, %{memory: 1}]
      query = %Query{sort_by: :memory, sort_dir: :desc, limit: 3}

      assert [%{memory: 5}, %{memory: 1}, %{other: :key}] = Query.paginate(query, rows)
    end

    test "a column holding both numbers and strings still orders" do
      # The runtime tables genuinely do this: os_pid is an integer for some
      # ports and :undefined for others.
      rows = [%{os_pid: 42}, %{os_pid: "undefined"}, %{os_pid: 7}]
      query = %Query{sort_by: :os_pid, sort_dir: :desc, limit: 3}

      assert [_, _, _] = Query.paginate(query, rows)
    end

    test "strings sort case-insensitively" do
      rows = [%{name: "zeta"}, %{name: "Alpha"}]
      query = %Query{sort_by: :name, sort_dir: :asc, limit: 2}

      assert [%{name: "Alpha"}, %{name: "zeta"}] = Query.paginate(query, rows)
    end

    test "without a sort column the rows keep their order" do
      rows = [%{n: 3}, %{n: 1}]

      assert ^rows = Query.paginate(%Query{sort_by: nil, limit: 5}, rows)
    end
  end
end
