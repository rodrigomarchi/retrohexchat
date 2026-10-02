defmodule RetroHexChatWeb.ContentDates do
  @moduledoc """
  When each public page last actually changed, for the sitemap's `lastmod`.

  `lastmod` is the one field of the sitemap protocol a search engine still
  reads, and it is the only thing that tells it which of four thousand help
  URLs are worth coming back for. It is also the easiest to get wrong: stamping
  the deploy time on every page says everything changed every release, which is
  how a crawler learns to ignore the field altogether.

  So the date comes from the content's own history. A help topic's body and a
  landing page's markup are files in git, and git knows when each last changed.
  One `git log` at compile time turns that into a map, and a page with no entry
  gets **no `lastmod` at all** rather than a guess — the sitemap may be silent
  about a page, but it may not lie about one.

  Captured at compile time, which is also when the content is frozen: a release
  compiles from a checkout, so the dates ship with the pages they describe. When
  git is not there to ask — a build from a tarball — the map is empty and every
  `lastmod` is simply omitted.
  """

  @help_content_dir "apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/help_content"
  @landing_dir "apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/landing_live"

  # One pass over the log of the two directories, newest commit first, so the
  # first date a path appears under is the last time it changed.
  @dates (fn ->
            case System.cmd(
                   "git",
                   [
                     "log",
                     "--format=C%cI",
                     "--name-only",
                     "--",
                     # `:(top)` makes the pathspec relative to the repository
                     # root rather than to `cd:`, which is a directory deep
                     # inside it.
                     ":(top)" <> @help_content_dir,
                     ":(top)" <> @landing_dir
                   ],
                   cd: __DIR__,
                   stderr_to_stdout: true
                 ) do
              {output, 0} ->
                output
                |> String.split("\n", trim: true)
                |> Enum.reduce({nil, %{}}, fn
                  "C" <> timestamp, {_current, dates} ->
                    {timestamp |> String.slice(0, 10), dates}

                  path, {current, dates} when is_binary(current) ->
                    {current, Map.put_new(dates, path, current)}

                  _line, acc ->
                    acc
                end)
                |> elem(1)

              _other ->
                %{}
            end
          end).()

  @doc """
  The day a public landing path last changed, or `nil`.
  """
  @spec landing(String.t()) :: String.t() | nil
  def landing(path) do
    case landing_basename(path) do
      nil -> nil
      base -> first_date(["#{@landing_dir}/#{base}.html.heex", "#{@landing_dir}/#{base}.ex"])
    end
  end

  @doc """
  The day a help topic's body last changed, or `nil`.

  The help index has no body of its own, so it answers with the most recent day
  any topic changed — which is the day the page a reader opens last differed.
  """
  @spec help_topic(String.t()) :: String.t() | nil
  def help_topic("welcome"), do: newest_help_date()

  def help_topic(topic_id) do
    file = String.replace(topic_id, "-", "_")

    first_date(["#{@help_content_dir}/#{file}.html.heex"])
  end

  @doc """
  Whether any date is known at all.

  False in a build with no git, and the sitemap then omits every `lastmod`.
  """
  @spec known?() :: boolean()
  def known?, do: @dates != %{}

  defp first_date(candidates), do: Enum.find_value(candidates, &Map.get(@dates, &1))

  defp newest_help_date do
    @dates
    |> Enum.filter(fn {path, _date} -> String.starts_with?(path, @help_content_dir) end)
    |> Enum.map(&elem(&1, 1))
    |> Enum.max(fn -> nil end)
  end

  defp landing_basename("/"), do: "index"
  defp landing_basename("/" <> rest), do: String.replace(rest, "-", "_")
  defp landing_basename(_path), do: nil
end
