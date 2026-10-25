defmodule RetroHexChat.Schema.LifecycleTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  defmodule Visit do
    use Ecto.Schema
    import Ecto.Changeset

    use RetroHexChat.Schema.Lifecycle,
      statuses: ~w(open closed expired),
      terminal: ~w(closed expired),
      terminal_fields: [:closed_at]

    embedded_schema do
      field :status, :string
      field :closed_at, :utc_datetime
    end

    def changeset(attrs) do
      %__MODULE__{}
      |> cast(attrs, [:status, :closed_at])
      |> validate_inclusion(:status, @status_values)
      |> validate_terminal_fields()
    end
  end

  test "names its statuses and which of them end a record" do
    assert Visit.status_values() == ~w(open closed expired)
    assert Visit.terminal_statuses() == ~w(closed expired)
    assert Visit.terminal?("expired")
    refute Visit.terminal?("open")
  end

  test "asks for the terminal fields only once the status is terminal" do
    assert Visit.changeset(%{status: "open"}).valid?
    refute Visit.changeset(%{status: "closed"}).valid?
    assert Visit.changeset(%{status: "closed", closed_at: DateTime.utc_now()}).valid?
  end
end
