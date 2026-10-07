defmodule RetroHexChatWeb.HelpLive.ContentIndex do
  @moduledoc """
  What each help topic's own text already says, read from its template at compile time.

  The page around a topic adds two things the template may already carry: the
  topic's description and the "See Also" links from its metadata. Reading the
  templates once tells the page which of them would repeat what the reader has
  just read, so each appears once.
  """

  alias RetroHexChat.Chat.HelpTopics

  @dir Path.expand("../../controllers/help_content", __DIR__)
  @files @dir |> Path.join("*.html.heex") |> Path.wildcard() |> Enum.sort()
  @files_hash :erlang.md5(@files)

  for file <- @files, do: @external_resource(file)

  # A description sharing this much of its vocabulary with the topic's first
  # sentence says the same thing twice.
  @repeat_overlap 0.6

  @help_link ~r/<\.help_link\s+topic="([^"]+)"/
  @see_also_heading ~r/dgettext\("[a-z_]+",\s*"See Also"\)/
  @first_string ~r/dgettext\("[a-z_]+",\s*"((?:[^"\\]|\\.)*)"/s

  @templates Map.new(@files, fn file ->
               body = File.read!(file)
               id = file |> Path.basename(".html.heex") |> String.replace("_", "-")

               opening =
                 case Regex.run(@first_string, body) do
                   [_, text] -> text
                   nil -> ""
                 end

               {id,
                %{
                  links:
                    @help_link
                    |> Regex.scan(body, capture: :all_but_first)
                    |> List.flatten()
                    |> MapSet.new(),
                  see_also?: Regex.match?(@see_also_heading, body),
                  opening: opening
                }}
             end)

  words = fn text ->
    text |> String.downcase() |> String.split(~r/[^a-z0-9]+/, trim: true) |> MapSet.new()
  end

  @repeating for %{id: id, description: description} <- HelpTopics.all_topics(),
                 entry = Map.get(@templates, id),
                 entry != nil,
                 described = words.(description),
                 MapSet.size(described) > 0,
                 MapSet.size(MapSet.intersection(described, words.(entry.opening))) /
                   MapSet.size(described) >= @repeat_overlap,
                 into: MapSet.new(),
                 do: id

  @doc false
  def __mix_recompile__?,
    do:
      @dir |> Path.join("*.html.heex") |> Path.wildcard() |> Enum.sort() |> :erlang.md5() !=
        @files_hash

  @doc "The topic ids the template links to."
  @spec body_links(String.t()) :: MapSet.t(String.t())
  def body_links(topic_id), do: topic_id |> entry() |> Map.fetch!(:links)

  @doc "Whether the template ends with its own See Also section."
  @spec see_also?(String.t()) :: boolean()
  def see_also?(topic_id), do: topic_id |> entry() |> Map.fetch!(:see_also?)

  @doc """
  Whether the topic's description repeats its template's opening sentence.

  Decided once, in English, the language both are written in: a translation of
  either follows its source.
  """
  @spec description_repeats_opening?(String.t()) :: boolean()
  def description_repeats_opening?(topic_id), do: MapSet.member?(@repeating, topic_id)

  @empty %{links: MapSet.new(), see_also?: false, opening: ""}

  defp entry(topic_id), do: Map.get(@templates, topic_id, @empty)
end
