defmodule RetroHexChat.Radio do
  @moduledoc """
  Hex Radio's stations: the most played, a genre's, a search by name and the
  reader's favourites, from the catalog configured as `:radio_catalog`
  (`RetroHexChat.Radio.Catalog`).

  The stream itself never passes through the server: the reader's browser
  plays the station's address. The server only lists, keeps the lists for a
  while (`Radio.Cache`) and tells the catalog when a station was played.
  """

  alias RetroHexChat.Radio.{Cache, Catalog, RadioBrowser, Station}

  require Logger

  # The genres the window lists, as the catalog tags them.
  @genres ~w(chiptune synthwave 80s 90s lofi jazz rock pop electronic classical ambient metal reggae news)

  @limit 100
  @max_ids 50
  @min_search 2
  @max_search 60

  @doc "The genres Hex Radio lists, as catalog tags."
  @spec genres() :: [String.t()]
  def genres, do: @genres

  @doc """
  The playable stations for `query`, most played first.

  A genre must be one of `genres/0`, a search between #{@min_search} and
  #{@max_search} characters, and favourites at most #{@max_ids} ids; anything
  else is `{:error, :invalid}` without asking the catalog. A catalog that
  cannot answer is `{:error, :unavailable}`.
  """
  @spec list(Catalog.query()) :: {:ok, [Station.t()]} | {:error, :invalid | :unavailable}
  def list(query) do
    with {:ok, query} <- validate(query) do
      cached(query)
    end
  end

  @doc "Tells the catalog the station `id` was played. Never fails the caller."
  @spec played(String.t()) :: :ok
  def played(id) when is_binary(id) and byte_size(id) in 1..64, do: catalog().played(id)
  def played(_id), do: :ok

  defp validate(:top), do: {:ok, :top}
  defp validate({:tag, tag} = query) when tag in @genres, do: {:ok, query}

  defp validate({:name, text}) when is_binary(text) do
    text = String.trim(text)

    if String.length(text) in @min_search..@max_search,
      do: {:ok, {:name, text}},
      else: {:error, :invalid}
  end

  defp validate({:ids, []}), do: {:ok, {:ids, []}}

  defp validate({:ids, ids}) when is_list(ids) and length(ids) <= @max_ids do
    if Enum.all?(ids, &(is_binary(&1) and byte_size(&1) in 1..64)),
      do: {:ok, {:ids, Enum.uniq(ids)}},
      else: {:error, :invalid}
  end

  defp validate(_query), do: {:error, :invalid}

  defp cached({:ids, []}), do: {:ok, []}

  defp cached(query) do
    case Cache.get(query) do
      {:ok, stations} ->
        {:ok, stations}

      :miss ->
        with {:ok, stations} <- fetch(query) do
          Cache.put(query, stations)
          {:ok, stations}
        end
    end
  end

  defp fetch(query) do
    case catalog().records(query, @limit) do
      {:ok, records} ->
        {:ok, records |> stations() |> in_order(query)}

      {:error, reason} ->
        Logger.warning("radio: the catalog did not answer #{inspect(query)}: #{inspect(reason)}")
        {:error, :unavailable}
    end
  end

  defp stations(records) do
    records
    |> Enum.flat_map(fn record ->
      case Station.from_record(record) do
        {:ok, station} -> [station]
        :skip -> []
      end
    end)
    |> Enum.uniq_by(& &1.stream)
  end

  # Favourites keep the order they were starred in.
  defp in_order(stations, {:ids, ids}) do
    by_id = Map.new(stations, &{&1.id, &1})
    for id <- ids, station = by_id[id], do: station
  end

  defp in_order(stations, _query), do: stations

  defp catalog, do: Application.get_env(:retro_hex_chat, :radio_catalog, RadioBrowser)
end
