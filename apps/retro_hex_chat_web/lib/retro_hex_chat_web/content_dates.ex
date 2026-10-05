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
  @game_shots_dir "apps/retro_hex_chat_web/priv/static/images/games"

  # What a game's page is drawn from besides its template: the two catalogues
  # its text comes from, the web catalogue and the cards that shape it.
  @game_sources [
    "apps/retro_hex_chat/lib/retro_hex_chat/arcade/catalog.ex",
    "apps/retro_hex_chat/lib/retro_hex_chat/games/catalog.ex",
    "apps/retro_hex_chat_web/lib/retro_hex_chat_web/game_catalog.ex",
    "apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/landing/game_cards.ex"
  ]

  # What every guide is drawn from besides its own template.
  @guide_sources [
    "apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/landing_live/guides.ex",
    "apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/landing/irc_guides.ex"
  ]

  # The mIRC commands page's rows.
  @mirc_parity "apps/retro_hex_chat/lib/retro_hex_chat/commands/mirc_parity.ex"

  # The commit the dates below were read at. History moves without any source
  # file of this module changing, so Mix is told to recompile it whenever the
  # checkout's HEAD is no longer that commit — otherwise a build keeps the
  # dates of whichever commit it first compiled at.
  @compiled_head (case System.cmd("git", ["rev-parse", "HEAD"],
                         cd: __DIR__,
                         stderr_to_stdout: true
                       ) do
                    {sha, 0} -> String.trim(sha)
                    _other -> nil
                  end)

  @doc false
  @spec __mix_recompile__?() :: boolean()
  def __mix_recompile__?, do: current_head() != @compiled_head

  defp current_head do
    case System.cmd("git", ["rev-parse", "HEAD"], cd: __DIR__, stderr_to_stdout: true) do
      {sha, 0} -> String.trim(sha)
      _other -> nil
    end
  end

  # One pass over the log of every public page's sources, newest commit first,
  # so the first date a path appears under is the last time it changed.
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
                     ":(top)" <> @landing_dir,
                     ":(top)" <> @game_shots_dir
                   ] ++
                     Enum.map(
                       @game_sources ++ @guide_sources ++ [@mirc_parity],
                       &(":(top)" <> &1)
                     ),
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
  def landing("/mirc-commands"), do: guide("mirc_commands", [@mirc_parity])
  def landing("/mirc-online"), do: guide("mirc_online", [])
  def landing("/irc-chat"), do: guide("irc_chat", [])

  def landing(path) do
    case landing_basename(path) do
      nil -> nil
      base -> newest_date(["#{@landing_dir}/#{base}.html.heex", "#{@landing_dir}/#{base}.ex"])
    end
  end

  @doc """
  The day a game's page last changed, or `nil`: the newest of its template,
  the catalogues and cards it is drawn from, and its own screenshot.
  """
  @spec game_page(String.t()) :: String.t() | nil
  def game_page(slug) do
    newest_date(
      [
        "#{@landing_dir}/game.html.heex",
        "#{@landing_dir}/game.ex",
        "#{@game_shots_dir}/#{slug}.webp"
      ] ++ @game_sources
    )
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

    newest_date(["#{@help_content_dir}/#{file}.html.heex"])
  end

  @doc """
  Whether any date is known at all.

  False in a build with no git, and the sitemap then omits every `lastmod`.
  """
  @spec known?() :: boolean()
  def known?, do: @dates != %{}

  # A guide changes when its template, the pieces every guide shares, or the
  # data it is drawn from does.
  defp guide(base, sources) do
    newest_date(
      ["#{@landing_dir}/#{base}.html.heex", "#{@landing_dir}/#{base}.ex"] ++
        @guide_sources ++ sources
    )
  end

  # The newest of the days any of `candidates` changed: a page changes when any
  # of what it is drawn from does. ISO dates compare correctly as strings.
  defp newest_date(candidates) do
    candidates
    |> Enum.map(&Map.get(@dates, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> nil end)
  end

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
