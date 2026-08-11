defmodule RetroHexChat.ChangesetErrors do
  @moduledoc """
  What a changeset refused, in words a person can read.

  Ecto stores an error as the message plus the values to interpolate into it —
  `{"should be at most %{count} character(s)", [count: 30]}` — so turning one
  into a sentence always means the same substitution. Four places were doing
  that substitution, all identically.

  Only the substitution is shared. How the fields are then joined into a
  sentence, and which catalogue that sentence is translated in, stays with the
  caller: a validation failure shown by a service reads differently from one
  shown by a command, and each already has its own translations.
  """

  @doc """
  Every error, interpolated, by field.

  The values a caller needs are the interpolated strings; the shape is Ecto's
  own, so a field with two failures reports both.
  """
  @spec by_field(Ecto.Changeset.t()) :: %{atom() => [String.t()]}
  def by_field(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _whole, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
