defmodule RetroHexChat.SystemInfo.SourcesTest do
  @moduledoc """
  Every source is exercised against the live VM rather than a fixture.

  These modules exist to report what the runtime actually holds, so a mock
  would only prove the mock's shape. The emulator running the suite is a real
  node with real processes, ports, tables and applications, and asserting
  against it is the only way these tests can catch the failure that matters:
  an OTP function whose return shape is not what the code expects.
  """

  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.SystemInfo
  alias RetroHexChat.SystemInfo.Source
  alias RetroHexChat.SystemInfo.Sources.Processes
  alias RetroHexChat.Table

  describe "every source" do
    # Driven off the registry rather than a copy of it, so a source added to
    # the context is covered here without anyone remembering to add it.
    for name <- RetroHexChat.SystemInfo.source_names() do
      @tag source: name
      test "#{name} lists rows carrying every column it declares" do
        {:ok, source} = SystemInfo.fetch_source(unquote(name))

        table = SystemInfo.list(source, SystemInfo.query(source, %{"limit" => "5"}))

        assert %Table{} = table
        assert length(table.rows) <= 5
        assert table.total >= length(table.rows)

        for row <- table.rows, column <- table.columns do
          assert Map.has_key?(row, column.key),
                 "#{unquote(name)} row is missing declared column #{column.key}"
        end
      end

      test "#{name} gives every row an id for the DOM to key on" do
        {:ok, source} = SystemInfo.fetch_source(unquote(name))
        table = SystemInfo.list(source, SystemInfo.query(source, %{"limit" => "5"}))

        assert Enum.all?(table.rows, &Map.has_key?(&1, :id))
      end

      test "#{name} sorts by its own default without being asked" do
        {:ok, source} = SystemInfo.fetch_source(unquote(name))
        table = SystemInfo.list(source, SystemInfo.query(source, %{}))

        assert source.default_sort() in Source.column_keys(source)
        assert %Table{} = table
      end

      test "#{name} honours the limit" do
        {:ok, source} = SystemInfo.fetch_source(unquote(name))
        table = SystemInfo.list(source, SystemInfo.query(source, %{"limit" => "2"}))

        assert length(table.rows) <= 2
      end

      test "#{name} narrows the population when searched, without ever growing it" do
        {:ok, source} = SystemInfo.fetch_source(unquote(name))

        all = SystemInfo.list(source, SystemInfo.query(source, %{"limit" => "500"}))

        filtered =
          SystemInfo.list(
            source,
            SystemInfo.query(source, %{"limit" => "500", "search" => "zzz_no_such_entity_zzz"})
          )

        assert filtered.total == 0
        assert filtered.total <= all.total
      end
    end
  end

  describe "processes" do
    test "finds a process by its registered name" do
      {:ok, source} = SystemInfo.fetch_source(:processes)

      table =
        SystemInfo.list(source, SystemInfo.query(source, %{"search" => "code_server"}))

      assert Enum.any?(table.rows, &(&1.name =~ "code_server"))
    end

    test "the page carries the OTP callback module, not proc_lib's entry point" do
      {:ok, source} = SystemInfo.fetch_source(:processes)

      table = SystemInfo.list(source, SystemInfo.query(source, %{"limit" => "100"}))

      refute Enum.any?(table.rows, &(&1.name =~ "proc_lib.init_p")),
             "enrichment should have replaced proc_lib entry points with real initial calls"
    end

    # The scan and the enrichment are two separate reads of the same process,
    # and a busy node is a node where things die between them. A row that
    # missed enrichment carries `proc_lib.init_p/5`, which is exactly the name
    # this source exists to remove — so it is dropped rather than published.
    test "a process that dies between the scan and the enrichment is dropped" do
      pid = spawn(fn -> Process.sleep(:infinity) end)
      row = %{id: inspect(pid), raw_pid: pid, name: "proc_lib.init_p/5"}

      assert [%{name: "proc_lib.init_p/5"}] = Processes.enrich([row])

      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, _pid, _reason}

      assert Processes.enrich([row]) == []
    end

    test "sorting by mailbox depth is available, which is the point of the window" do
      {:ok, source} = SystemInfo.fetch_source(:processes)

      query = SystemInfo.query(source, %{"sort_by" => "message_queue_len", "sort_dir" => "desc"})
      table = SystemInfo.list(source, query)

      depths = Enum.map(table.rows, & &1.message_queue_len)
      assert depths == Enum.sort(depths, :desc)
    end
  end

  describe "ets" do
    test "reports memory in bytes rather than the words the runtime returns" do
      {:ok, source} = SystemInfo.fetch_source(:ets)

      table = SystemInfo.list(source, SystemInfo.query(source, %{"limit" => "1"}))
      [row | _] = table.rows

      word_size = :erlang.system_info(:wordsize)
      assert rem(row.memory, word_size) == 0
      assert row.memory >= word_size
    end
  end

  describe "applications" do
    test "reports this very application as loaded and started" do
      {:ok, source} = SystemInfo.fetch_source(:applications)

      table =
        SystemInfo.list(source, SystemInfo.query(source, %{"search" => "retro_hex_chat"}))

      assert Enum.any?(table.rows, &(&1.name == "retro_hex_chat" and &1.started))
    end
  end

  describe "fetch_source/1" do
    test "accepts the string form a window sends" do
      assert {:ok, _module} = SystemInfo.fetch_source("processes")
    end

    test "refuses an unknown name instead of raising" do
      assert {:error, :unknown_source} = SystemInfo.fetch_source("../../etc/passwd")
      assert {:error, :unknown_source} = SystemInfo.fetch_source(:nope)
    end
  end
end
