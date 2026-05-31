defmodule RetroHexChat.Commands.Autocomplete do
  @moduledoc """
  Provides fuzzy matching and search functions for the autocomplete system.

  Supports three autocomplete modes:
  - Commands: fuzzy search with categories and recent commands
  - Nicknames: search channel users with status/color metadata
  - Channels: search visible channels with user counts and joined status

  All matching is done server-side using subsequence-based fuzzy matching.
  """
  use Gettext, backend: RetroHexChat.Gettext

  # Result types

  @type command_result :: %{
          type: :command,
          name: String.t(),
          description: String.t(),
          category: String.t(),
          category_atom: atom(),
          recent?: boolean(),
          score: non_neg_integer(),
          matched_chars: [non_neg_integer()]
        }

  @type nick_result :: %{
          type: :nick,
          nickname: String.t(),
          status: :online | :away,
          away_message: String.t() | nil,
          color: String.t() | nil,
          self?: boolean(),
          score: non_neg_integer(),
          matched_chars: [non_neg_integer()]
        }

  @type channel_result :: %{
          type: :channel,
          name: String.t(),
          user_count: non_neg_integer(),
          topic: String.t() | nil,
          joined?: boolean(),
          score: non_neg_integer(),
          matched_chars: [non_neg_integer()]
        }

  @type subcommand_result :: %{
          type: :subcommand,
          name: String.t(),
          description: String.t(),
          score: non_neg_integer(),
          matched_chars: [non_neg_integer()]
        }

  @type autocomplete_result ::
          command_result() | nick_result() | channel_result() | subcommand_result()

  @type match_result :: {:match, non_neg_integer(), [non_neg_integer()]} | :no_match

  @max_results 20
  @category_order [:basics, :channel, :user, :config, :advanced]

  # --- Fuzzy Matching ---

  @doc """
  Performs fuzzy subsequence matching of `query` against `candidate`.

  Returns `{:match, score, matched_indices}` or `:no_match`.

  Scoring:
  - Exact prefix match: 1000 + length bonus
  - Word-boundary subsequence: 500
  - General subsequence: 100
  - No match: `:no_match`
  """
  @spec fuzzy_match(String.t(), String.t()) :: match_result()
  def fuzzy_match("", _candidate), do: {:match, 0, []}

  def fuzzy_match(query, candidate) do
    q = String.downcase(query)
    c = String.downcase(candidate)

    cond do
      String.starts_with?(c, q) ->
        indices = Enum.to_list(0..(String.length(q) - 1))
        {:match, 1000 + String.length(candidate), indices}

      word_boundary_match?(q, c) ->
        indices = word_boundary_indices(q, c)
        {:match, 500, indices}

      true ->
        case subsequence_indices(q, c) do
          {:ok, indices} -> {:match, 100, indices}
          :error -> :no_match
        end
    end
  end

  # --- Search Functions ---

  @doc """
  Searches commands using fuzzy matching, with category grouping and recent commands.
  """
  @spec search_commands(String.t(), [String.t()]) :: [String.t() | command_result()]
  def search_commands(partial, recent_commands) do
    alias RetroHexChat.Commands.Registry

    matches =
      Registry.command_metadata()
      |> Enum.map(&match_command(&1, partial, recent_commands))
      |> Enum.reject(&is_nil/1)

    limit =
      if partial == "" do
        :infinity
      else
        @max_results
      end

    matches
    |> Enum.sort_by(&{-&1.score, &1.name})
    |> grouped_command_results(recent_commands, limit)
  end

  defp grouped_command_results(matches, recent_commands, limit) do
    {recent_matches, remaining_matches} = split_recent_matches(matches, recent_commands)

    recent_items =
      if recent_matches == [] do
        []
      else
        [dgettext("commands", "Recent") | recent_matches]
      end

    remaining_limit = remaining_limit(limit, length(recent_matches))

    grouped_items =
      remaining_matches
      |> take_match_limit(remaining_limit)
      |> Enum.group_by(& &1.category_atom)
      |> grouped_by_category()

    recent_items ++ grouped_items
  end

  defp split_recent_matches(matches, recent_commands) do
    recent_lookup = MapSet.new(recent_commands)

    recent_matches =
      recent_commands
      |> Enum.flat_map(fn recent ->
        matches
        |> Enum.filter(&(&1.name == recent))
        |> Enum.take(1)
      end)

    remaining_matches =
      Enum.reject(matches, &MapSet.member?(recent_lookup, &1.name))

    {recent_matches, remaining_matches}
  end

  defp remaining_limit(:infinity, _used), do: :infinity
  defp remaining_limit(limit, used), do: max(limit - used, 0)

  defp take_match_limit(matches, :infinity), do: matches
  defp take_match_limit(matches, limit), do: Enum.take(matches, limit)

  defp grouped_by_category(grouped) do
    for category <- @category_order,
        commands = Map.get(grouped, category, []),
        commands != [],
        reduce: [] do
      acc ->
        label = commands |> hd() |> Map.fetch!(:category)
        acc ++ [label | Enum.sort_by(commands, & &1.name)]
    end
  end

  @doc """
  Returns only selectable command items from grouped search results.
  """
  @spec command_items([String.t() | command_result()]) :: [command_result()]
  def command_items(results) do
    Enum.reject(results, &is_binary/1)
  end

  defp match_command(cmd, partial, recent_commands) do
    case fuzzy_match(partial, cmd.name) do
      {:match, score, matched_chars} ->
        %{
          type: :command,
          name: cmd.name,
          description: cmd.description,
          category: cmd.category,
          category_atom: cmd.category_atom,
          recent?: cmd.name in recent_commands,
          score: score,
          matched_chars: matched_chars
        }

      :no_match ->
        nil
    end
  end

  @doc false
  @spec search_command_items(String.t(), [String.t()]) :: [command_result()]
  def search_command_items(partial, recent_commands) do
    partial
    |> search_commands(recent_commands)
    |> command_items()
  end

  @doc """
  Searches nicknames in a channel user list using fuzzy matching.
  Own nickname is deprioritized to the end of results.
  """
  @spec search_nicks(String.t(), [map()], String.t()) :: [nick_result()]
  def search_nicks(partial, channel_users, own_nickname) do
    channel_users
    |> Enum.map(&match_nick(&1, partial, own_nickname))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&{&1.self?, status_order(&1.status), -&1.score, &1.nickname})
    |> Enum.take(@max_results)
  end

  defp match_nick(user, partial, own_nickname) do
    case fuzzy_match(partial, user.nickname) do
      {:match, score, matched_chars} ->
        %{
          type: :nick,
          nickname: user.nickname,
          status: if(user.away, do: :away, else: :online),
          away_message: Map.get(user, :away_message),
          color_class: Map.get(user, :color_class),
          self?: user.nickname == own_nickname,
          score: score,
          matched_chars: matched_chars
        }

      :no_match ->
        nil
    end
  end

  defp status_order(:online), do: 0
  defp status_order(:away), do: 1

  @doc """
  Searches visible channels using fuzzy matching.
  Joined channels are sorted first. Secret channels excluded for non-members.
  """
  @spec search_channels(String.t(), [String.t()], [map()]) :: [channel_result()]
  def search_channels(partial, user_channels, channel_data) do
    channel_data
    |> Enum.map(&match_channel(&1, partial, user_channels))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&{!&1.joined?, -&1.score, &1.name})
    |> Enum.take(@max_results)
  end

  @spec search_channels(String.t(), [String.t()]) :: [channel_result()]
  def search_channels(partial, user_channels) do
    channel_data = list_visible_channels(user_channels)
    search_channels(partial, user_channels, channel_data)
  end

  defp match_channel(channel, partial, user_channels) do
    # Strip # prefix for matching
    name_without_hash = String.replace_leading(channel.name, "#", "")

    case fuzzy_match(partial, name_without_hash) do
      {:match, score, matched_chars} ->
        %{
          type: :channel,
          name: channel.name,
          user_count: channel.user_count,
          topic: Map.get(channel, :topic),
          joined?: channel.name in user_channels,
          score: score,
          matched_chars: matched_chars
        }

      :no_match ->
        nil
    end
  end

  @doc """
  Searches subcommands for a given parent command using fuzzy matching.
  """
  @spec search_subcommands(String.t(), String.t()) :: [subcommand_result()]
  def search_subcommands(command_name, partial) do
    alias RetroHexChat.Commands.{CommandSyntax, Registry}

    case Registry.get_syntax(command_name) do
      %CommandSyntax{subcommands: subs} when is_list(subs) ->
        subs
        |> Enum.map(&match_subcommand(&1, partial))
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(&{-&1.score, &1.name})
        |> Enum.take(@max_results)

      _ ->
        []
    end
  end

  defp match_subcommand(sub, partial) do
    case fuzzy_match(partial, sub.name) do
      {:match, score, matched_chars} ->
        %{
          type: :subcommand,
          name: sub.name,
          description: sub.description,
          score: score,
          matched_chars: matched_chars
        }

      :no_match ->
        nil
    end
  end

  @doc """
  Returns alphabetically sorted list of matching nicknames for Tab cycling.
  Uses prefix matching (not fuzzy). Own nick moved to end.
  """
  @spec tab_complete_matches(String.t(), [map()], String.t()) :: [String.t()]
  def tab_complete_matches(partial, channel_users, own_nickname) do
    downcased = String.downcase(partial)

    matches =
      channel_users
      |> Enum.filter(fn user ->
        String.downcase(user.nickname) |> String.starts_with?(downcased)
      end)
      |> Enum.map(& &1.nickname)
      |> Enum.sort()

    # Move own nick to end
    case Enum.split_with(matches, &(&1 != own_nickname)) do
      {others, [own]} -> others ++ [own]
      {all, []} -> all
    end
  end

  @doc """
  Given a command name, returns what type of argument it expects.

  Returns `{:nick, :all_channels}`, `{:nick, :current_channel}`,
  `{:channel, :all}`, or `nil`.
  """
  @nick_all_commands ~w(msg query whois whowas notice invite)
  @nick_current_commands ~w(kick ban)
  @channel_commands ~w(join part topic mode)

  @spec argument_context(String.t()) ::
          {:nick, :all_channels | :current_channel} | {:channel, :all} | nil
  def argument_context(command_name) when command_name in @nick_all_commands,
    do: {:nick, :all_channels}

  def argument_context(command_name) when command_name in @nick_current_commands,
    do: {:nick, :current_channel}

  def argument_context(command_name) when command_name in @channel_commands,
    do: {:channel, :all}

  def argument_context(_command_name), do: nil

  @doc """
  Lists visible channels with user counts, applying secret/private visibility rules.
  """
  @spec list_visible_channels([String.t()]) :: [map()]
  def list_visible_channels(user_channels) do
    alias RetroHexChat.Channels.{Registry, Server}

    Registry.registry_name()
    |> Elixir.Registry.select([{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.map(fn {channel_name, _pid} ->
      case Server.get_state(channel_name) do
        {:ok, state} ->
          apply_channel_visibility(channel_name, state, channel_name in user_channels)

        {:error, _} ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.name)
  end

  defp apply_channel_visibility(_channel_name, state, false = _is_member) do
    cond do
      Map.get(state.modes_detail, :secret, false) ->
        nil

      Map.get(state.modes_detail, :private, false) ->
        %{name: "Prv", topic: nil, user_count: state.member_count}

      true ->
        %{name: state.name, topic: state.topic, user_count: state.member_count}
    end
  end

  defp apply_channel_visibility(channel_name, state, true = _is_member) do
    %{name: channel_name, topic: state.topic, user_count: state.member_count}
  end

  # --- Private Helpers ---

  defp word_boundary_match?(query, candidate) do
    word_starts = get_word_start_positions(candidate)
    match_at_boundaries?(String.graphemes(query), candidate, word_starts, 0)
  end

  defp match_at_boundaries?([], _candidate, _word_starts, _pos), do: true

  defp match_at_boundaries?([char | rest], candidate, word_starts, pos) do
    candidate_chars = String.graphemes(candidate)

    Enum.find_index(Enum.drop(candidate_chars, pos), fn c ->
      c == char and (pos + index_in_dropped(candidate_chars, pos, c)) in word_starts
    end)
    |> case do
      nil ->
        # Fall back: try to match remaining chars anywhere
        false

      _ ->
        match_at_boundaries?(rest, candidate, word_starts, pos + 1)
    end
  end

  defp index_in_dropped(chars, drop_count, target) do
    chars
    |> Enum.drop(drop_count)
    |> Enum.find_index(&(&1 == target))
    |> Kernel.||(0)
  end

  defp word_boundary_indices(query, candidate) do
    q_chars = String.graphemes(query)
    c_chars = String.graphemes(candidate)
    word_starts = get_word_start_positions(candidate)
    find_boundary_indices(q_chars, c_chars, word_starts, 0, [])
  end

  defp find_boundary_indices([], _c_chars, _word_starts, _pos, acc),
    do: Enum.reverse(acc)

  defp find_boundary_indices([q | rest], c_chars, word_starts, pos, acc) do
    case find_next_match(q, c_chars, pos) do
      nil -> Enum.reverse(acc)
      idx -> find_boundary_indices(rest, c_chars, word_starts, idx + 1, [idx | acc])
    end
  end

  defp find_next_match(char, c_chars, from_pos) do
    c_chars
    |> Enum.with_index()
    |> Enum.drop_while(fn {_c, i} -> i < from_pos end)
    |> Enum.find_value(fn {c, i} -> if c == char, do: i end)
  end

  defp get_word_start_positions(str) do
    str
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce([0], fn {char, idx}, acc ->
      if char in ["-", "_", " "] do
        [idx + 1 | acc]
      else
        acc
      end
    end)
    |> MapSet.new()
  end

  defp subsequence_indices(query, candidate) do
    q_chars = String.graphemes(query)
    c_chars = String.graphemes(candidate)
    do_subsequence(q_chars, c_chars, 0, [])
  end

  defp do_subsequence([], _c_chars, _pos, acc), do: {:ok, Enum.reverse(acc)}

  defp do_subsequence([q | rest], c_chars, pos, acc) do
    case find_next_match(q, c_chars, pos) do
      nil -> :error
      idx -> do_subsequence(rest, c_chars, idx + 1, [idx | acc])
    end
  end
end
