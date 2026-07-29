defmodule RetroHexChat.Commands.Handlers.ServerProvisionTest do
  @moduledoc """
  Lints `scripts/server-provision.md` against the code that has to run it.

  The provisioning script is documentation that is also a program: an operator
  pastes it verbatim into the Admin Console. Nothing else in CI executes it, so
  it drifted — the previous version set `arcade_enabled`, a key the error message
  advertised and no clause ever handled, and the line failed silently in the
  middle of a paste.

  These are static checks, not an execution: every line must parse, name a real
  command, and use only settings and identifiers the handlers accept.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capabilities.Trivia.QuestionBank
  alias RetroHexChat.Commands.Handlers.Bot
  alias RetroHexChat.Commands.Registry

  @script_path Path.expand("../../../../../../scripts/server-provision.md", __DIR__)

  # Bot.ex validates both against these, so the script must respect them.
  @bot_name ~r/^[a-zA-Z][a-zA-Z0-9_-]*$/
  @command_trigger ~r/^[a-zA-Z0-9_-]+$/

  setup_all do
    body = File.read!(@script_path)

    lines =
      body
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      # The console skips blanks and #-comments; so does this.
      |> Enum.filter(&String.starts_with?(&1, "/"))

    {:ok, lines: lines}
  end

  defp args(line), do: line |> String.trim_leading("/") |> String.split(" ", trim: true)

  test "the script exists and carries commands" do
    assert File.exists?(@script_path)
  end

  test "every command names a handler the registry knows", %{lines: lines} do
    unknown =
      lines
      |> Enum.map(&args/1)
      |> Enum.map(&hd/1)
      |> Enum.uniq()
      |> Enum.reject(&Registry.known?/1)

    assert unknown == [], "script uses commands with no handler: #{inspect(unknown)}"
  end

  test "every /bot set uses a key /bot set accepts", %{lines: lines} do
    used =
      for ["bot", "set", _bot, key | _] <- Enum.map(lines, &args/1), uniq: true, do: key

    refute used == [], "expected the script to configure bots"

    unknown = Enum.reject(used, &(&1 in Bot.settings()))

    assert unknown == [],
           "script sets keys no apply_setting clause handles: #{inspect(unknown)}"
  end

  test "every bot name passes the nickname format bot.ex enforces", %{lines: lines} do
    # create/set/addcmd/join all carry the bot name in the same position.
    names =
      for ["bot", verb, name | _] <- Enum.map(lines, &args/1),
          verb in ~w(create set addcmd join part info),
          uniq: true,
          do: name

    refute names == []

    bad = Enum.reject(names, &Regex.match?(@bot_name, &1))
    assert bad == [], "bot names rejected by the schema: #{inspect(bad)}"
  end

  test "every custom command trigger passes the trigger format", %{lines: lines} do
    triggers =
      for ["bot", "addcmd", _bot, trigger | _] <- Enum.map(lines, &args/1),
          uniq: true,
          do: trigger

    refute triggers == []

    bad = Enum.reject(triggers, &Regex.match?(@command_trigger, &1))
    assert bad == [], "custom command triggers the schema rejects: #{inspect(bad)}"
  end

  test "every bot it configures, it first creates", %{lines: lines} do
    parsed = Enum.map(lines, &args/1)
    created = for ["bot", "create", name | _] <- parsed, uniq: true, do: name

    referenced =
      for ["bot", verb, name | _] <- parsed,
          verb in ~w(set addcmd join info),
          uniq: true,
          do: name

    assert referenced -- created == [],
           "configures bots it never creates: #{inspect(referenced -- created)}"
  end

  test "every channel a bot joins is a channel the script creates", %{lines: lines} do
    parsed = Enum.map(lines, &args/1)
    joined = for ["join", chan | _] <- parsed, uniq: true, do: String.downcase(chan)

    bot_targets =
      for ["bot", "join", _bot, chan | _] <- parsed, uniq: true, do: String.downcase(chan)

    assert bot_targets -- joined == [],
           "bots sent to channels the script never creates: #{inspect(bot_targets -- joined)}"
  end

  test "moderation and trivia values are ones their clauses accept", %{lines: lines} do
    parsed = Enum.map(lines, &args/1)

    for ["bot", "set", _bot, "mod_action", value | _] <- parsed do
      assert value in ~w(warn mute kick), "mod_action #{value} is rejected"
    end

    categories = QuestionBank.categories()

    for ["bot", "set", _bot, "trivia_category", value | _] <- parsed do
      assert value in categories, "trivia_category #{value} is not in the question bank"
    end
  end

  test "every trigger the script advertises is one a bot will answer", %{lines: lines} do
    # Custom commands answer to both `!trigger` and `!Bot trigger`. dice and
    # trivia only ever answer to the long form, so a topic promising `!answer`
    # or `!roll` promises silence — which is exactly what shipped the first time.
    parsed = Enum.map(lines, &args/1)
    bots = for ["bot", "create", name | _] <- parsed, into: MapSet.new(), do: name
    triggers = for ["bot", "addcmd", _bot, t | _] <- parsed, into: MapSet.new(), do: t

    advertised =
      lines
      |> Enum.flat_map(&Regex.scan(~r/(?<![\w!])!(\w+)/, &1, capture: :all_but_first))
      |> List.flatten()
      |> Enum.uniq()

    dangling =
      Enum.reject(advertised, fn token ->
        MapSet.member?(triggers, token) or MapSet.member?(bots, token)
      end)

    assert dangling == [],
           "script advertises triggers nothing answers: #{inspect(dangling)}"
  end

  test "the bot that stands in every room does not greet", %{lines: lines} do
    # One welcome per newcomer. A bot present in all channels would otherwise
    # double the greeting the room's own host already gives.
    parsed = Enum.map(lines, &args/1)
    joins = for ["bot", "join", bot, _chan | _] <- parsed, do: bot
    channels = for ["join", chan | _] <- parsed, uniq: true, do: chan

    omnipresent =
      joins
      |> Enum.frequencies()
      |> Enum.filter(fn {_bot, n} -> n == length(channels) end)
      |> Enum.map(&elem(&1, 0))

    refute omnipresent == [], "expected one bot to be in every channel"

    for bot <- omnipresent do
      greeting =
        Enum.find_value(parsed, fn
          ["bot", "set", ^bot, "greeting" | rest] -> Enum.join(rest, " ")
          _ -> nil
        end)

      assert greeting == "none",
             "#{bot} stands in every channel and must be set to 'greeting none'"
    end
  end

  test "every feed it seeds is one the bot can actually deliver", %{lines: lines} do
    # `/bot rss add <bot> <url> <channel>` fails at run time if the bot was never
    # created, was never put in that channel, or the address is one the guard
    # refuses. All three are visible here, before anyone pastes the script.
    parsed = Enum.map(lines, &args/1)
    created = for ["bot", "create", name | _] <- parsed, into: MapSet.new(), do: name

    memberships =
      for ["bot", "join", bot, chan | _] <- parsed,
          into: MapSet.new(),
          do: {bot, String.downcase(chan)}

    seeded = for ["bot", "rss", "add", bot, url, chan | _] <- parsed, do: {bot, url, chan}

    refute seeded == [], "expected the script to seed feeds"

    for {bot, url, chan} <- seeded do
      assert MapSet.member?(created, bot), "#{bot} carries a feed but is never created"

      assert MapSet.member?(memberships, {bot, String.downcase(chan)}),
             "#{bot} is told to post to #{chan} but never joins it"

      assert String.starts_with?(url, "http://") or String.starts_with?(url, "https://"),
             "#{url} is not an address the guard will fetch"
    end
  end

  test "a feed is seeded only after its bot is in the room", %{lines: lines} do
    parsed = Enum.map(lines, &args/1)

    {_joined, offenders} =
      Enum.reduce(parsed, {MapSet.new(), []}, fn
        ["bot", "join", bot, chan | _], {joined, bad} ->
          {MapSet.put(joined, {bot, String.downcase(chan)}), bad}

        ["bot", "rss", "add", bot, _url, chan | _], {joined, bad} ->
          key = {bot, String.downcase(chan)}
          {joined, if(MapSet.member?(joined, key), do: bad, else: [key | bad])}

        _line, acc ->
          acc
      end)

    assert offenders == [],
           "feeds seeded before the bot joins the room: #{inspect(offenders)}"
  end

  test "no channel is topic'd or moded before it is joined", %{lines: lines} do
    parsed = Enum.map(lines, &args/1)

    {_current, offenders} =
      Enum.reduce(parsed, {nil, []}, fn
        ["join", chan | _], {_cur, bad} -> {String.downcase(chan), bad}
        [verb | _], {nil, bad} when verb in ~w(topic mode cs) -> {nil, [verb | bad]}
        _line, acc -> acc
      end)

    assert offenders == [],
           "acts on the active channel before any /join: #{inspect(Enum.uniq(offenders))}"
  end
end
