defmodule RetroHexChat.Commands.AutocompleteChannelsTest do
  @moduledoc """
  What `/list` and the channel window are told about, now that the catalogue
  includes channels nobody is holding open.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  import ExUnit.Callbacks, only: [on_exit: 1]

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Commands.Autocomplete
  alias RetroHexChat.Services.Queries, as: ServiceQueries

  defp unique(prefix), do: "##{prefix}#{System.unique_integer([:positive])}"

  defp register_channel(name, opts \\ []) do
    {:ok, _} = ServiceQueries.insert_registered_channel(name, "Founder")

    ServiceQueries.update_registered_channel_settings(name,
      modes: Keyword.get(opts, :modes, ""),
      topic: Keyword.get(opts, :topic, "")
    )

    on_exit(fn ->
      case ServiceQueries.find_registered_channel(name) do
        nil -> :ok
        channel -> ServiceQueries.delete_registered_channel(channel)
      end
    end)

    name
  end

  defp start_channel(name) do
    case Registry.lookup(name) do
      {:ok, pid} -> pid
      {:error, :not_found} -> start_supervised_channel(name)
    end
  end

  defp start_supervised_channel(name) do
    {:ok, pid} = Supervisor.start_child(name)
    on_exit(fn -> if Process.alive?(pid), do: Supervisor.stop_child(Supervisor, pid) end)
    pid
  end

  describe "list_visible_channels/2" do
    test "a registered channel with nobody in it is offered" do
      name = register_channel(unique("visicold"))

      row = Enum.find(Autocomplete.list_visible_channels([]), &(&1.name == name))

      assert row
      assert row.user_count == 0
      refute row.joined?
    end

    test "a cold channel stored as secret is never named" do
      name = register_channel(unique("visisecret"), modes: "+s")

      refute Enum.any?(Autocomplete.list_visible_channels([]), &(&1.name == name)),
             "a stored +s leaked the existence of a channel nobody could list"
    end

    test "a cold channel stored as private is only a placeholder" do
      name = register_channel(unique("visiprivate"), modes: "+p")

      rows = Autocomplete.list_visible_channels([])

      refute Enum.any?(rows, &(&1.name == name))
      assert Enum.any?(rows, &(&1.name == "Prv"))
    end

    test "a channel the viewer is already in is marked joined, cold or not" do
      name = register_channel(unique("visijoined"))

      row = Enum.find(Autocomplete.list_visible_channels([name]), &(&1.name == name))

      assert row.joined?
    end

    test "the search term reaches the cold half" do
      name = register_channel(unique("visisearch"), topic: "amiga demoscene")

      rows = Autocomplete.list_visible_channels([], search: "amiga demoscene")

      assert Enum.any?(rows, &(&1.name == name))
    end

    test "a live channel is not listed twice when it is also registered" do
      name = register_channel(unique("visiboth"))
      start_channel(name)

      assert [_one] = Enum.filter(Autocomplete.list_visible_channels([]), &(&1.name == name))
    end
  end
end
