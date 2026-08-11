defmodule RetroHexChat.ChangesetErrorsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  import Ecto.Changeset

  alias RetroHexChat.ChangesetErrors

  defmodule Thing do
    @moduledoc false
    use Ecto.Schema

    embedded_schema do
      field :name, :string
      field :note, :string
    end
  end

  defp changeset(attrs) do
    %Thing{} |> cast(attrs, [:name, :note])
  end

  test "a required field says so" do
    errors =
      %{}
      |> changeset()
      |> validate_required([:name])
      |> ChangesetErrors.by_field()

    assert %{name: ["can't be blank"]} = errors
  end

  # The point of the module: Ecto stores the message and the values apart, so
  # anything reading an error has to put them back together.
  test "the numbers Ecto keeps beside the message are put into it" do
    errors =
      %{name: String.duplicate("x", 40)}
      |> changeset()
      |> validate_length(:name, max: 30)
      |> ChangesetErrors.by_field()

    assert %{name: [message]} = errors
    assert message =~ "30"
    refute message =~ "%{count}"
  end

  test "a field that failed twice reports both" do
    errors =
      %{name: "x"}
      |> changeset()
      |> validate_length(:name, min: 5)
      |> validate_format(:name, ~r/^\d+$/)
      |> ChangesetErrors.by_field()

    assert %{name: messages} = errors
    assert length(messages) == 2
  end

  test "every field that failed is there" do
    errors =
      %{}
      |> changeset()
      |> validate_required([:name, :note])
      |> ChangesetErrors.by_field()

    assert Map.keys(errors) |> Enum.sort() == [:name, :note]
  end

  test "a changeset that refused nothing reports nothing" do
    assert ChangesetErrors.by_field(changeset(%{name: "fine"})) == %{}
  end
end
