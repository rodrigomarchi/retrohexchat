defmodule RetroHexChat.Repo do
  use Ecto.Repo,
    otp_app: :retro_hex_chat,
    adapter: Ecto.Adapters.Postgres

  @doc """
  A `LIKE`/`ILIKE` pattern matching any value that contains `term` literally.

  `%`, `_` and the escape character `\\` mean something to `LIKE`; a person
  searching for `50%`, `a_b` or `C:\\temp` means the characters themselves, so
  all three are escaped. Every substring search goes through here.
  """
  @spec contains_pattern(String.t()) :: String.t()
  def contains_pattern(term) when is_binary(term) do
    escaped =
      term
      |> String.replace("\\", "\\\\")
      |> String.replace("%", "\\%")
      |> String.replace("_", "\\_")

    "%" <> escaped <> "%"
  end
end
