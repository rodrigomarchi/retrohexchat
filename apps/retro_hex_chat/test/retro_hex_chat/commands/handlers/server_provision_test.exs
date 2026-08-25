defmodule RetroHexChat.Commands.Handlers.ServerProvisionTest do
  @moduledoc """
  Lints every script in `docs/provisioning/` against the code that has to run it.

  A provisioning script is documentation that is also a program: an operator
  pastes it verbatim into the Admin Console. Nothing else in CI executes it, so
  it drifted — the first version set `arcade_enabled`, a key the error message
  advertised and no clause ever handled, and the line failed silently in the
  middle of a paste.

  These are static checks, not an execution: every line must parse, name a real
  command, and use only settings and identifiers the handlers accept. The scripts
  also share one server, so channel and bot names are checked for collisions
  across the whole directory, not only within a file.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capabilities.Trivia.QuestionBank
  alias RetroHexChat.Chat.{Formatter, IrcEscapes}
  alias RetroHexChat.Commands.Handlers.Bot
  alias RetroHexChat.Commands.Registry

  @dir Path.expand("../../../../../../docs/provisioning", __DIR__)
  @base Path.join(@dir, "en.md")

  # Bot.ex validates both against these, so the script must respect them.
  @bot_name ~r/^[a-zA-Z][a-zA-Z0-9_-]*$/
  @command_trigger ~r/^[a-zA-Z0-9_-]+$/
  # chat_helpers.ex only linkifies channel mentions that match this.
  @channel_name ~r/^#[a-zA-Z][a-zA-Z0-9_-]{0,49}$/

  defp scripts do
    @dir
    |> Path.join("*.md")
    |> Path.wildcard()
    |> Enum.reject(&(Path.basename(&1) == "README.md"))
    |> Enum.sort()
  end

  defp read(path) do
    body = File.read!(path)

    lines =
      body
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      # The console skips blanks and #-comments; so does this.
      |> Enum.filter(&String.starts_with?(&1, "/"))

    {body, lines, Enum.map(lines, &args/1)}
  end

  defp args(line), do: line |> String.trim_leading("/") |> String.split(" ", trim: true)

  # The bots that actually say something when somebody walks in. The moderator
  # every script puts in every room is set to `greeting none` and is not one.
  defp speaking_greeters(parsed) do
    for ["bot", "set", bot, "greeting" | rest] <- parsed,
        Enum.join(rest, " ") != "none",
        uniq: true,
        do: bot
  end

  defp setting(parsed, bot, key) do
    Enum.find_value(parsed, fn
      ["bot", "set", ^bot, ^key | rest] -> Enum.join(rest, " ")
      _line -> nil
    end)
  end

  defp visible_line(line), do: line |> IrcEscapes.decode() |> Formatter.strip()

  defp triggers_advertised(text) do
    ~r/(?<![\w!])!(\w+)/
    |> Regex.scan(text, capture: :all_but_first)
    |> List.flatten()
  end

  setup_all do
    {:ok, scripts: scripts()}
  end

  test "the directory carries the base script and one per enabled locale", %{scripts: scripts} do
    assert File.exists?(@base)

    locales =
      "config/i18n_locales.exs"
      |> Path.expand(Path.join(@dir, "../.."))
      |> Code.eval_file()
      |> elem(0)
      |> Enum.filter(&(&1.status == :enabled))
      |> Enum.map(& &1.code)

    present = Enum.map(scripts, &Path.basename(&1, ".md"))

    assert Enum.sort(present) == Enum.sort(locales),
           "provisioning scripts and enabled locales disagree: " <>
             inspect(%{missing: locales -- present, extra: present -- locales})
  end

  test "the English base keeps its shape" do
    {_body, _lines, parsed} = read(@base)
    channels = for ["join", chan | _] <- parsed, uniq: true, do: String.downcase(chan)
    bots = for ["bot", "create", name | _] <- parsed, uniq: true, do: name

    assert length(channels) == 12
    assert length(bots) == 21
  end

  test "the English narrative does not drift back to the old room count or RSS bootstrap" do
    {body, _lines, _parsed} = read(@base)

    refute body =~ "all 7"
    refute body =~ "seven rooms"
    refute body =~ "posts one headline"
    refute body =~ "A newly added feed posts"
    refute body =~ "https://www.cisa.gov/cybersecurity-advisories/all.xml"
    refute body =~ "https://us-cert.cisa.gov/ncas/alerts.xml"
    refute body =~ "https://rss.tecmundo.com.br/feed"
  end

  test "only the base script sets server-wide settings", %{scripts: scripts} do
    for path <- scripts, path != @base do
      {_body, _lines, parsed} = read(path)
      server = for ["admin", "server", "set", key | _] <- parsed, do: key

      assert server == [],
             "#{Path.basename(path)} sets server-wide keys #{inspect(server)}; " <>
               "the last script pasted would win for everyone"
    end
  end

  test "a language script opens at least ten rooms, each with a feed", %{scripts: scripts} do
    for path <- scripts, path != @base do
      {_body, _lines, parsed} = read(path)
      channels = for ["join", chan | _] <- parsed, uniq: true, do: String.downcase(chan)

      fed =
        for ["bot", "rss", "add", _bot, _url, chan | _] <- parsed,
            uniq: true,
            do: String.downcase(chan)

      assert length(channels) >= 10,
             "#{Path.basename(path)} opens #{length(channels)} rooms, fewer than ten"

      assert channels -- fed == [],
             "#{Path.basename(path)} opens rooms with no feed: #{inspect(channels -- fed)}"
    end
  end

  test "channel and bot names are unique across the whole directory", %{scripts: scripts} do
    owners =
      Enum.flat_map(scripts, fn path ->
        {_body, _lines, parsed} = read(path)
        file = Path.basename(path)

        channels = for ["join", chan | _] <- parsed, uniq: true, do: {String.downcase(chan), file}
        bots = for ["bot", "create", name | _] <- parsed, uniq: true, do: {name, file}

        channels ++ bots
      end)

    clashes =
      owners
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.filter(fn {_name, files} -> length(files) > 1 end)

    assert clashes == [],
           "the same name is claimed by more than one script: #{inspect(clashes)}"
  end

  test "every channel name is one the client will linkify", %{scripts: scripts} do
    for path <- scripts do
      {_body, _lines, parsed} = read(path)
      channels = for ["join", chan | _] <- parsed, uniq: true, do: chan

      bad = Enum.reject(channels, &Regex.match?(@channel_name, &1))

      assert bad == [],
             "#{Path.basename(path)} opens rooms the message linkifier cannot match: #{inspect(bad)}"
    end
  end

  test "every command names a handler the registry knows", %{scripts: scripts} do
    for path <- scripts do
      {_body, lines, _parsed} = read(path)

      unknown =
        lines
        |> Enum.map(&args/1)
        |> Enum.map(&hd/1)
        |> Enum.uniq()
        |> Enum.reject(&Registry.known?/1)

      assert unknown == [],
             "#{Path.basename(path)} uses commands with no handler: #{inspect(unknown)}"
    end
  end

  test "every /bot set uses a key /bot set accepts", %{scripts: scripts} do
    for path <- scripts do
      {_body, _lines, parsed} = read(path)
      used = for ["bot", "set", _bot, key | _] <- parsed, uniq: true, do: key

      refute used == [], "expected #{Path.basename(path)} to configure bots"

      unknown = Enum.reject(used, &(&1 in Bot.settings()))

      assert unknown == [],
             "#{Path.basename(path)} sets keys no apply_setting clause handles: #{inspect(unknown)}"
    end
  end

  test "every bot name passes the nickname format bot.ex enforces", %{scripts: scripts} do
    for path <- scripts do
      {_body, _lines, parsed} = read(path)

      # create/set/addcmd/join all carry the bot name in the same position.
      names =
        for ["bot", verb, name | _] <- parsed,
            verb in ~w(create set addcmd join part info),
            uniq: true,
            do: name

      refute names == []

      bad = Enum.reject(names, &Regex.match?(@bot_name, &1))

      assert bad == [],
             "#{Path.basename(path)} names bots the schema rejects: #{inspect(bad)}"
    end
  end

  test "every custom command trigger passes the trigger format", %{scripts: scripts} do
    for path <- scripts do
      {_body, _lines, parsed} = read(path)
      triggers = for ["bot", "addcmd", _bot, trigger | _] <- parsed, uniq: true, do: trigger

      refute triggers == []

      bad = Enum.reject(triggers, &Regex.match?(@command_trigger, &1))

      assert bad == [],
             "#{Path.basename(path)} uses triggers the schema rejects: #{inspect(bad)}"
    end
  end

  test "every bot it configures, it first creates", %{scripts: scripts} do
    for path <- scripts do
      {_body, _lines, parsed} = read(path)
      created = for ["bot", "create", name | _] <- parsed, uniq: true, do: name

      referenced =
        for ["bot", verb, name | _] <- parsed,
            verb in ~w(set addcmd join info),
            uniq: true,
            do: name

      assert referenced -- created == [],
             "#{Path.basename(path)} configures bots it never creates: " <>
               inspect(referenced -- created)
    end
  end

  test "every channel a bot joins is a channel the script creates", %{scripts: scripts} do
    for path <- scripts do
      {_body, _lines, parsed} = read(path)
      joined = for ["join", chan | _] <- parsed, uniq: true, do: String.downcase(chan)

      bot_targets =
        for ["bot", "join", _bot, chan | _] <- parsed, uniq: true, do: String.downcase(chan)

      assert bot_targets -- joined == [],
             "#{Path.basename(path)} sends bots to channels it never creates: " <>
               inspect(bot_targets -- joined)
    end
  end

  test "moderation and trivia values are ones their clauses accept", %{scripts: scripts} do
    categories = QuestionBank.categories()

    for path <- scripts do
      {_body, _lines, parsed} = read(path)

      for ["bot", "set", _bot, "mod_action", value | _] <- parsed do
        assert value in ~w(warn mute kick), "mod_action #{value} is rejected"
      end

      for ["bot", "set", _bot, "trivia_category", value | _] <- parsed do
        assert value in categories, "trivia_category #{value} is not in the question bank"
      end
    end
  end

  test "a trigger a bot advertises is one that same bot answers", %{scripts: scripts} do
    # Custom commands answer to `!trigger` and `!Bot trigger`, but only for the
    # bot that owns them. A greeting promising `!fontes` from a bot with no
    # `fontes` command promises silence — and the promise reads as a bug in the
    # room, not in the script.
    for path <- scripts do
      {_body, _lines, parsed} = read(path)
      bots = for ["bot", "create", name | _] <- parsed, into: MapSet.new(), do: name

      owned =
        Enum.reduce(parsed, %{}, fn
          ["bot", "addcmd", bot, trigger | _], acc ->
            Map.update(acc, bot, MapSet.new([trigger]), &MapSet.put(&1, trigger))

          _line, acc ->
            acc
        end)

      speech =
        for ["bot", verb, bot | rest] <- parsed,
            verb in ~w(set addcmd),
            do: {bot, visible_line(Enum.join(rest, " "))}

      dangling =
        for {bot, text} <- speech,
            token <- triggers_advertised(text),
            not MapSet.member?(bots, token),
            not MapSet.member?(Map.get(owned, bot, MapSet.new()), token),
            do: "#{bot} advertises !#{token}"

      assert dangling == [],
             "#{Path.basename(path)}: #{inspect(Enum.uniq(dangling))}"
    end

    # Topics advertise on behalf of the room, so the trigger must belong to a bot
    # that is actually in that room.
    for path <- scripts do
      {_body, lines, parsed} = read(path)
      bots = for ["bot", "create", name | _] <- parsed, into: MapSet.new(), do: name

      owned =
        Enum.reduce(parsed, %{}, fn
          ["bot", "addcmd", bot, trigger | _], acc ->
            Map.update(acc, bot, MapSet.new([trigger]), &MapSet.put(&1, trigger))

          _line, acc ->
            acc
        end)

      residents =
        Enum.reduce(parsed, %{}, fn
          ["bot", "join", bot, chan | _], acc ->
            Map.update(acc, String.downcase(chan), [bot], &[bot | &1])

          _line, acc ->
            acc
        end)

      {_current, dangling} =
        Enum.reduce(lines, {nil, []}, fn line, {current, bad} ->
          case args(line) do
            ["join", chan | _] ->
              {String.downcase(chan), bad}

            ["topic" | rest] ->
              in_room = Map.get(residents, current, [])

              answered =
                in_room
                |> Enum.flat_map(&MapSet.to_list(Map.get(owned, &1, MapSet.new())))
                |> MapSet.new()

              missing =
                for token <- triggers_advertised(visible_line(Enum.join(rest, " "))),
                    not MapSet.member?(bots, token),
                    not MapSet.member?(answered, token),
                    do: "#{current} promises !#{token}"

              {current, missing ++ bad}

            _other ->
              {current, bad}
          end
        end)

      assert dangling == [],
             "#{Path.basename(path)}: #{inspect(Enum.uniq(dangling))}"
    end
  end

  test "the bot that stands in every room does not greet", %{scripts: scripts} do
    # One welcome per newcomer. A bot present in all channels would otherwise
    # double the greeting the room's own host already gives.
    for path <- scripts do
      {_body, _lines, parsed} = read(path)
      joins = for ["bot", "join", bot, _chan | _] <- parsed, do: bot
      channels = for ["join", chan | _] <- parsed, uniq: true, do: chan

      omnipresent =
        joins
        |> Enum.frequencies()
        |> Enum.filter(fn {_bot, n} -> n == length(channels) end)
        |> Enum.map(&elem(&1, 0))

      refute omnipresent == [],
             "#{Path.basename(path)}: expected one bot to be in every channel"

      for bot <- omnipresent do
        greeting =
          Enum.find_value(parsed, fn
            ["bot", "set", ^bot, "greeting" | rest] -> Enum.join(rest, " ")
            _ -> nil
          end)

        assert greeting == "none",
               "#{bot} stands in every channel of #{Path.basename(path)} and must be " <>
                 "set to 'greeting none'"
      end
    end
  end

  test "no room is greeted twice", %{scripts: scripts} do
    for path <- scripts do
      {_body, _lines, parsed} = read(path)

      greeters =
        for ["bot", "set", bot, "greeting" | rest] <- parsed,
            Enum.join(rest, " ") != "none",
            into: MapSet.new(),
            do: bot

      crowded =
        parsed
        |> Enum.flat_map(fn
          ["bot", "join", bot, chan | _] -> [{String.downcase(chan), bot}]
          _line -> []
        end)
        |> Enum.filter(fn {_chan, bot} -> MapSet.member?(greeters, bot) end)
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
        |> Enum.filter(fn {_chan, bots} -> length(Enum.uniq(bots)) > 1 end)

      assert crowded == [],
             "#{Path.basename(path)} greets a newcomer more than once: #{inspect(crowded)}"
    end
  end

  test "room greeters are private and deduplicated", %{scripts: scripts} do
    for path <- scripts do
      {_body, _lines, parsed} = read(path)

      greetings =
        for ["bot", "set", bot, "greeting" | rest] <- parsed,
            Enum.join(rest, " ") != "none",
            uniq: true,
            do: bot

      refute greetings == [],
             "#{Path.basename(path)}: expected the script to configure room greeters"

      for bot <- greetings do
        delivery =
          Enum.find_value(parsed, fn
            ["bot", "set", ^bot, "greeting_delivery", value | _] -> value
            _ -> nil
          end)

        repeat_window =
          Enum.find_value(parsed, fn
            ["bot", "set", ^bot, "greeter_repeat_window", value | _] -> value
            _ -> nil
          end)

        assert delivery == "private_notice",
               "#{bot} greets users but does not set greeting_delivery private_notice"

        assert is_binary(repeat_window) and String.to_integer(repeat_window) > 0,
               "#{bot} greets users but does not set a positive greeter_repeat_window"
      end
    end
  end

  test "every room greeter announces newcomers and teaches IRC", %{scripts: scripts} do
    # The greeting says what the room is. It cannot also say what IRC is, because
    # it is one line and the room half is the half that has to differ per room.
    for path <- scripts do
      {_body, _lines, parsed} = read(path)

      for bot <- speaking_greeters(parsed) do
        assert setting(parsed, bot, "public_greeting"),
               "#{bot} greets #{Path.basename(path)} but never announces a newcomer to the room"

        assert setting(parsed, bot, "onboarding_1"),
               "#{bot} greets #{Path.basename(path)} but teaches no IRC"
      end
    end
  end

  test "the IRC half of a welcome is the same in every room of a script", %{scripts: scripts} do
    # Whichever door somebody comes through teaches the same thing, and a fix to
    # the wording reaches every room or none. The repetition is the point: each
    # script writes these lines in its own language, so they cannot live in one
    # place, and without this they drift a room at a time.
    for path <- scripts do
      {_body, _lines, parsed} = read(path)
      greeters = speaking_greeters(parsed)

      for key <- ~w(onboarding_1 onboarding_2) do
        variants =
          greeters
          |> Enum.map(&{&1, setting(parsed, &1, key)})
          |> Enum.reject(fn {_bot, value} -> is_nil(value) end)
          |> Enum.group_by(fn {_bot, value} -> value end, fn {bot, _value} -> bot end)

        assert map_size(variants) <= 1,
               "#{Path.basename(path)}: #{key} differs between rooms: " <>
                 inspect(Enum.map(variants, fn {value, bots} -> {bots, value} end))
      end
    end
  end

  test "onboarding is delivered privately in the seed scripts", %{scripts: scripts} do
    # Same reason `greeting_delivery` is pinned: the newcomer is oriented inside
    # the room without turning everyone else's scrollback into bot chatter.
    for path <- scripts do
      {_body, _lines, parsed} = read(path)

      for bot <- speaking_greeters(parsed),
          delivery = setting(parsed, bot, "onboarding_delivery"),
          delivery != nil do
        assert delivery == "private_notice",
               "#{bot} in #{Path.basename(path)} sets onboarding_delivery #{delivery}"
      end
    end
  end

  test "the one public line of a welcome stays short", %{scripts: scripts} do
    # It is the only part of a welcome everyone in the room reads, and the only
    # part that persists. The orientation goes in the private half, which is why
    # there is a private half at all.
    for path <- scripts do
      {_body, _lines, parsed} = read(path)

      too_long =
        for bot <- speaking_greeters(parsed),
            announcement = setting(parsed, bot, "public_greeting"),
            announcement != nil,
            visible = visible_line(announcement),
            String.length(visible) > 90,
            do: "#{bot} (#{String.length(visible)})"

      assert too_long == [],
             "#{Path.basename(path)}: public greetings the whole room reads are too long: " <>
               inspect(too_long)
    end
  end

  test "seeded bot speech carries IRC colour escapes", %{scripts: scripts} do
    for path <- scripts do
      {_body, _lines, parsed} = read(path)

      speech =
        for ["bot", "set", bot, key | rest] <- parsed,
            key in ~w(greeting public_greeting onboarding_1 onboarding_2 onboarding_3
                      onboarding_4 mention_response mod_warn),
            Enum.join(rest, " ") != "none" do
          {bot, key, Enum.join(rest, " ")}
        end ++
          for ["bot", "addcmd", bot, trigger | rest] <- parsed do
            {bot, "addcmd #{trigger}", Enum.join(rest, " ")}
          end

      refute speech == [], "#{Path.basename(path)}: expected seeded bot speech"

      missing_colour =
        speech
        |> Enum.reject(fn {_bot, _key, value} -> String.contains?(value, "\\c") end)
        |> Enum.map(fn {bot, key, _value} -> "#{bot} #{key}" end)

      assert missing_colour == [],
             "#{Path.basename(path)} seeds speech without colour: #{inspect(missing_colour)}"
    end
  end

  test "automatic farewells stay disabled in the seed scripts", %{scripts: scripts} do
    for path <- scripts do
      {_body, _lines, parsed} = read(path)

      offenders =
        for ["bot", "set", bot, "farewell" | rest] <- parsed,
            Enum.join(rest, " ") != "none",
            do: bot

      assert offenders == [],
             "#{Path.basename(path)}: farewells become noisy on reconnect churn: " <>
               inspect(offenders)
    end
  end

  test "every feed it seeds is one the bot can actually deliver", %{scripts: scripts} do
    # `/bot rss add <bot> <url> <channel>` fails at run time if the bot was never
    # created, was never put in that channel, or the address is one the guard
    # refuses. All three are visible here, before anyone pastes the script.
    for path <- scripts do
      {_body, _lines, parsed} = read(path)
      created = for ["bot", "create", name | _] <- parsed, into: MapSet.new(), do: name

      memberships =
        for ["bot", "join", bot, chan | _] <- parsed,
            into: MapSet.new(),
            do: {bot, String.downcase(chan)}

      seeded = for ["bot", "rss", "add", bot, url, chan | _] <- parsed, do: {bot, url, chan}

      refute seeded == [], "#{Path.basename(path)}: expected the script to seed feeds"

      for {bot, url, chan} <- seeded do
        assert MapSet.member?(created, bot), "#{bot} carries a feed but is never created"

        assert MapSet.member?(memberships, {bot, String.downcase(chan)}),
               "#{bot} is told to post to #{chan} but never joins it"

        assert String.starts_with?(url, "http://") or String.starts_with?(url, "https://"),
               "#{url} is not an address the guard will fetch"
      end
    end
  end

  test "no bot is given more feeds than its own limit allows", %{scripts: scripts} do
    # `max_feeds` defaults to 5 and `rss add` refuses the sixth silently enough
    # that a pasted script looks like it worked.
    for path <- scripts do
      {_body, _lines, parsed} = read(path)

      limits =
        for ["bot", "set", bot, "rss_max_feeds", value | _] <- parsed,
            into: %{},
            do: {bot, String.to_integer(value)}

      counts =
        parsed
        |> Enum.flat_map(fn
          ["bot", "rss", "add", bot | _] -> [bot]
          _line -> []
        end)
        |> Enum.frequencies()

      over =
        for {bot, count} <- counts, count > Map.get(limits, bot, 5), do: "#{bot}=#{count}"

      assert over == [],
             "#{Path.basename(path)} seeds more feeds than max_feeds allows: #{inspect(over)}"
    end
  end

  test "a feed is seeded only after its bot is in the room", %{scripts: scripts} do
    for path <- scripts do
      {_body, _lines, parsed} = read(path)

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
             "#{Path.basename(path)} seeds feeds before the bot joins: #{inspect(offenders)}"
    end
  end

  test "no channel is topic'd or moded before it is joined", %{scripts: scripts} do
    for path <- scripts do
      {_body, _lines, parsed} = read(path)

      {_current, offenders} =
        Enum.reduce(parsed, {nil, []}, fn
          ["join", chan | _], {_cur, bad} -> {String.downcase(chan), bad}
          [verb | _], {nil, bad} when verb in ~w(topic mode cs) -> {nil, [verb | bad]}
          _line, acc -> acc
        end)

      assert offenders == [],
             "#{Path.basename(path)} acts on the active channel before any /join: " <>
               inspect(Enum.uniq(offenders))
    end
  end
end
