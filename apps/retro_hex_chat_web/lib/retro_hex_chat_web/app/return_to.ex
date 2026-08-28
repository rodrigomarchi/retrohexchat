defmodule RetroHexChatWeb.App.ReturnTo do
  @moduledoc """
  Where a connect may send someone afterwards.

  Following a shared link without a session means connecting first and arriving
  second, so the destination has to survive a round trip through a form field
  the client controls. That makes this the one place in the app where a value
  from outside decides a redirect, and the only safe way to hold it is an
  allowlist: a path that starts with one of the app's own prefixes, and nothing
  else.

  Refusing is not an error the caller handles. There is always somewhere
  sensible to go, and a login that dead-ends because a query string was odd is
  worse than one that quietly lands in the chat.

  A path may carry a locale segment, because every public page in this app also
  exists under one and a shared link may well be the localized version. Only
  the segments the router registers are stripped — an arbitrary first path
  segment is not a way past the allowlist.

  The rejected shapes are the interesting part, and each is a technique rather
  than a hypothetical: `//host` is scheme-relative and leaves the origin,
  `/\\host` and `\\\\host` are normalised to that by browsers, an absolute URL
  leaves outright, and `..` walks out of the path space the prefixes describe.
  """

  @default "/chat"
  @prefixes ~w(/chat /join/ /play /call/ /space/ /p2p/)
  @max_length 512

  # Read from the same source the router builds its localized scopes from, so a
  # locale added there cannot become a path refused here.
  @locale_segments RetroHexChatWeb.SEO.localized_locale_segments()

  @doc "The path to land on after connecting, or the chat when the value is not one."
  @spec sanitize(term()) :: String.t()
  def sanitize(path) when is_binary(path) do
    if allowed?(path), do: path, else: @default
  end

  def sanitize(_path), do: @default

  @doc "The path used when nothing else is allowed."
  @spec default() :: String.t()
  def default, do: @default

  defp allowed?(path) do
    byte_size(path) <= @max_length and
      String.starts_with?(path, "/") and
      not String.starts_with?(path, "//") and
      not String.contains?(path, "\\") and
      not String.contains?(path, "..") and
      matches_prefix?(strip_locale(path))
  end

  defp matches_prefix?(path), do: Enum.any?(@prefixes, &prefix_match?(path, &1))

  # Every public page in this app also exists under a locale segment, so a
  # shared link may carry one. Only the segments the router actually registers
  # count: an arbitrary first segment is not a way past the allowlist.
  defp strip_locale(path) do
    Enum.find_value(@locale_segments, path, fn segment ->
      prefix = "/" <> segment

      cond do
        path == prefix -> "/"
        String.starts_with?(path, prefix <> "/") -> String.replace_prefix(path, prefix, "")
        true -> nil
      end
    end)
  end

  # `/chat` and `/play` match themselves as well as their sub-paths; the ones
  # written with a trailing slash only ever have sub-paths.
  defp prefix_match?(path, prefix) do
    if String.ends_with?(prefix, "/") do
      String.starts_with?(path, prefix)
    else
      path == prefix or String.starts_with?(path, prefix <> "/") or
        String.starts_with?(path, prefix <> "?")
    end
  end
end
