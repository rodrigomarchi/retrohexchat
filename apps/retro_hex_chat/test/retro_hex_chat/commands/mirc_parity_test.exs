defmodule RetroHexChat.Commands.MircParityTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChat.Commands.MircParity
  alias RetroHexChat.Commands.Registry

  test "every command a row points to can be typed here" do
    for %{here: here} = row <- MircParity.rows(), here do
      assert Registry.known?(here), "#{row.mirc} points to /#{here}, which is not a command"
    end
  end

  test "a row says what to do instead exactly when it is not the same" do
    for row <- MircParity.rows() do
      case row.status do
        :same -> assert row.here && is_nil(row.note), "#{row.mirc} is the same and needs no note"
        :different -> assert row.here && row.note, "#{row.mirc} must name the command and how"
        :missing -> assert is_nil(row.here) && row.note, "#{row.mirc} must say what to do instead"
      end
    end
  end

  # How a command is typed here is an identifier: it is shown as written,
  # outside the translated note, and it is a command this server knows.
  test "a row's usage is typed with the command it points to" do
    for %{usage: usage, here: here} = row <- MircParity.rows(), usage do
      assert String.starts_with?(usage, "/#{here}"), "#{row.mirc}: #{usage} is not /#{here}"
    end
  end

  test "a help topic is offered only when it exists" do
    linked = for %{help_topic: id} <- MircParity.rows(), id, do: id

    assert linked != []
    assert Enum.all?(linked, &HelpTopics.get_topic/1)
  end

  test "every row belongs to a group, and no mIRC command is listed twice" do
    groups = Keyword.keys(MircParity.groups())
    rows = MircParity.rows()

    assert Enum.all?(rows, &(&1.group in groups))
    assert rows |> Enum.map(& &1.mirc) |> Enum.uniq() |> length() == length(rows)
    assert Enum.all?(groups, &(MircParity.rows(&1) != []))
  end
end
