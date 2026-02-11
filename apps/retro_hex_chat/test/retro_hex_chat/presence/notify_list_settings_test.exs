defmodule RetroHexChat.Presence.NotifyListSettingsTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Presence.NotifyListSettings

  describe "changeset/2" do
    test "valid with owner_nickname" do
      cs = NotifyListSettings.changeset(%NotifyListSettings{}, %{owner_nickname: "Alice"})
      assert cs.valid?
    end

    test "auto_whois defaults to false" do
      settings = %NotifyListSettings{}
      assert settings.auto_whois == false
    end

    test "invalid without owner_nickname" do
      cs = NotifyListSettings.changeset(%NotifyListSettings{}, %{})
      refute cs.valid?
      assert errors_on(cs)[:owner_nickname]
    end

    test "accepts auto_whois true" do
      cs =
        NotifyListSettings.changeset(%NotifyListSettings{}, %{
          owner_nickname: "Alice",
          auto_whois: true
        })

      assert cs.valid?
      assert Ecto.Changeset.get_change(cs, :auto_whois) == true
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
