defmodule RetroHexChat.SystemInfo.AllocatorsTest do
  @moduledoc """
  Run against the live emulator, because the shape of `allocator_sizes` is the
  thing most likely to break here and no fixture would ever catch that: the
  property lists it returns hold four-element tuples, which the Keyword module
  cannot read at all.
  """

  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.SystemInfo

  describe "allocators/0" do
    test "reads every allocator the emulator exposes" do
      readings = SystemInfo.allocators()
      expected = :erlang.system_info(:alloc_util_allocators)

      # One row per allocator, plus the synthetic total.
      assert length(readings) == length(expected) + 1
    end

    test "the total leads, because the breakdown only means something against it" do
      assert [%{name: :total} | _rest] = SystemInfo.allocators()
    end

    test "the total is the sum of the allocators beneath it" do
      [total | readings] = SystemInfo.allocators()

      assert total.block_size == readings |> Enum.map(& &1.block_size) |> Enum.sum()
      assert total.carrier_size == readings |> Enum.map(& &1.carrier_size) |> Enum.sum()
    end

    test "sizes are read, not silently zeroed by a shape mismatch" do
      [total | _rest] = SystemInfo.allocators()

      assert total.block_size > 0, "block sizes came back empty — the property shape changed"
      assert total.carrier_size > 0, "carrier sizes came back empty — the property shape changed"
    end

    test "carriers hold at least the blocks cut out of them" do
      [total | _rest] = SystemInfo.allocators()

      assert total.carrier_size >= total.block_size
      assert total.max_carrier_size >= total.carrier_size
    end

    test "block totals are the same order of magnitude as reported memory" do
      # Not equal — allocator accounting and :erlang.memory/0 count different
      # things — but a shape bug shows up as orders of magnitude, not percent.
      [total | _rest] = SystemInfo.allocators()
      reported = :erlang.memory(:total)

      assert total.block_size > div(reported, 10)
      assert total.block_size < reported * 10
    end

    test "every reading carries the columns declared for it" do
      keys = Enum.map(SystemInfo.allocator_columns(), & &1.key)

      for reading <- SystemInfo.allocators(), key <- keys do
        assert Map.has_key?(reading, key)
      end
    end

    test "utilisation is the share of held memory actually in use" do
      [total | _rest] = SystemInfo.allocators()

      assert_in_delta total.utilisation, total.block_size / total.carrier_size * 100, 0.0001
      assert total.utilisation > 0.0 and total.utilisation <= 100.0
    end

    test "an allocator holding no carriers reports no utilisation rather than dividing by zero" do
      # Some allocators are configured off and report zeroes throughout; the
      # reading has to survive them.
      idle = Enum.filter(SystemInfo.allocators(), &(&1.carrier_size == 0))

      assert Enum.all?(idle, &(&1.utilisation == 0.0))
    end
  end
end
