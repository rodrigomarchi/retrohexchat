defmodule RetroHexChat.CatalogText do
  @moduledoc """
  The text fields of a catalogue entry — the games' and the arcade's —
  translated when the entry is read.

  Every text field is a msgid translated at read time, never when the module
  compiles: a description concatenated from two msgids at compile time matched
  nothing in a catalog, and one split mid-sentence translated each half
  without the other.
  """

  @fields [:tagline, :description, :controls]

  @spec translate(map(), String.t()) :: map()
  def translate(entry, domain) do
    Enum.reduce(@fields, entry, fn field, acc ->
      Map.update!(acc, field, &Gettext.dgettext(RetroHexChat.Gettext, domain, &1))
    end)
  end
end
