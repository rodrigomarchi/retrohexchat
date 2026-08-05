defmodule RetroHexChat.SystemInfo.RuntimeTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.SystemInfo
  alias RetroHexChat.SystemInfo.{Memory, Usage}

  describe "info/1" do
    test "describes the emulator running the suite" do
      info = SystemInfo.info()

      assert info.banner =~ "Erlang/OTP"
      assert info.architecture =~ "-"
      assert info.atom_limit > 0
      assert info.process_limit > 0
      assert info.port_limit > 0
    end

    test "reports the version of each application named" do
      info = SystemInfo.info([:elixir, :retro_hex_chat])

      assert [%{app: :elixir, version: elixir}, %{app: :retro_hex_chat, version: app}] =
               info.versions

      assert elixir == System.version()
      assert is_binary(app)
    end

    test "an application that is not loaded reports nil rather than vanishing" do
      info = SystemInfo.info([:no_such_application])

      assert [%{app: :no_such_application, version: nil}] = info.versions
    end
  end

  describe "usage/0" do
    test "counts every bounded resource against its ceiling" do
      usage = SystemInfo.usage()

      for gauge <- [usage.atoms, usage.ports, usage.processes] do
        assert %Usage{} = gauge
        assert gauge.used > 0
        assert gauge.used <= gauge.limit
        assert gauge.percent >= 0.0 and gauge.percent <= 100.0
      end
    end

    test "the IO run queue is the part of the backlog that is not CPU" do
      usage = SystemInfo.usage()

      assert usage.io_run_queue == usage.total_run_queue - usage.cpu_run_queue
      assert usage.io_run_queue >= 0
    end

    test "uptime and IO counters are non-negative and moving forward" do
      first = SystemInfo.usage()
      Process.sleep(15)
      second = SystemInfo.usage()

      assert second.uptime_ms >= first.uptime_ms
      assert second.input_bytes >= 0
      assert second.output_bytes >= 0
    end
  end

  describe "memory" do
    test "the buckets account for the whole total, which is what lets it be one bar" do
      memory = SystemInfo.usage().memory

      sum =
        memory
        |> Memory.buckets()
        |> Enum.map(&elem(&1, 1))
        |> Enum.sum()

      assert sum == memory.total
    end

    test "every bucket is offered in display order" do
      memory = SystemInfo.usage().memory

      assert [:processes, :atom, :binary, :code, :ets, :other] =
               memory |> Memory.buckets() |> Enum.map(&elem(&1, 0))
    end

    test "shares add up to a hundred percent" do
      memory = SystemInfo.usage().memory

      total =
        [:processes, :atom, :binary, :code, :ets, :other]
        |> Enum.map(&Memory.share(memory, &1))
        |> Enum.sum()

      assert_in_delta total, 100.0, 0.0001
    end

    test "a zero total is survivable rather than a division by zero" do
      empty = %Memory{
        total: 0,
        processes: 0,
        atom: 0,
        binary: 0,
        code: 0,
        ets: 0,
        other: 0
      }

      assert Memory.share(empty, :processes) == 0.0
    end
  end

  describe "Usage" do
    test "percent is the used fraction of the limit" do
      usage = Usage.new(25, 100)

      assert usage.percent == 25.0
      assert Usage.percent_rounded(usage) == 25.0
    end

    test "a barely-touched resource rounds to zero rather than to noise" do
      usage = Usage.new(4, 100_000)

      assert Usage.percent_rounded(usage) == 0.0
      assert Usage.percent_rounded(usage, 3) == 0.004
    end
  end
end
