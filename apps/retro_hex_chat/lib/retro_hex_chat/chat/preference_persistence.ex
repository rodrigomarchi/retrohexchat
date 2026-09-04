defmodule RetroHexChat.Chat.PreferencePersistence do
  @moduledoc """
  Durable outbox for registered-user preference and list saves.

  LiveViews enqueue the latest in-memory snapshot here. Oban applies the latest
  pending snapshot through the existing domain `save/2` functions, coalescing
  repeated UI mutations for the same user and preference type.
  """

  import Ecto.Query

  alias RetroHexChat.Accounts.{ContactList, NickColors}

  alias RetroHexChat.Chat.{
    AliasList,
    AutoJoinList,
    AutoRespondRules,
    CustomMenus,
    FloodProtection,
    HighlightWords,
    IgnoreList,
    InputHistory,
    PerformList,
    PreferencePersistence.Request,
    SoundSettings
  }

  alias RetroHexChat.Jobs
  alias RetroHexChat.Jobs.PreferenceSaveWorker
  alias RetroHexChat.Presence.NotifyList
  alias RetroHexChat.Repo

  @type preference_type ::
          :notify_list
          | :contacts
          | :nick_colors
          | :highlight_words
          | :ignore_list
          | :perform_list
          | :autojoin_list
          | :input_history
          | :aliases
          | :custom_menus
          | :autorespond_rules
          | :flood_protection
          | :sound_settings

  @type enqueue_result :: :ok | {:error, term()}

  @types [
    :notify_list,
    :contacts,
    :nick_colors,
    :highlight_words,
    :ignore_list,
    :perform_list,
    :autojoin_list,
    :input_history,
    :aliases,
    :custom_menus,
    :autorespond_rules,
    :flood_protection,
    :sound_settings
  ]

  @enum_value_keys [:ignore_type, :menu_type, :trigger_event]

  @spec types() :: [preference_type()]
  def types, do: @types

  @spec enqueue(String.t(), preference_type() | String.t(), term()) :: enqueue_result()
  def enqueue(owner_nickname, preference_type, snapshot)
      when is_binary(owner_nickname) and owner_nickname != "" do
    with {:ok, type} <- normalize_type(preference_type),
         payload <- encode_payload(snapshot),
         {:ok, request} <- upsert_request(owner_nickname, type, payload),
         {:ok, _job} <-
           Jobs.insert(
             PreferenceSaveWorker.new(%{
               owner_nickname: request.owner_nickname,
               preference_type: request.preference_type
             })
           ) do
      :ok
    end
  end

  def enqueue(_owner_nickname, _preference_type, _snapshot), do: {:error, :invalid_owner}

  @spec apply_pending(String.t(), String.t(), keyword()) ::
          {:ok, :applied | :already_applied} | {:cancel, String.t()} | {:error, term()}
  def apply_pending(owner_nickname, preference_type, opts \\ []) do
    attempt = Keyword.get(opts, :attempt, 1)

    case get_request(owner_nickname, preference_type) do
      nil ->
        {:cancel, "request not found"}

      %Request{} = request ->
        apply_request(request, attempt)
    end
  end

  @spec get_request(String.t(), String.t()) :: Request.t() | nil
  def get_request(owner_nickname, preference_type) do
    Repo.get_by(Request, owner_nickname: owner_nickname, preference_type: preference_type)
  end

  @spec stats(keyword()) :: [map()]
  def stats(opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    Request
    |> group_by([request], [request.preference_type, request.status])
    |> select([request], %{
      preference_type: request.preference_type,
      status: request.status,
      count: count(request.id),
      payload_size_bytes: sum(request.payload_size_bytes),
      oldest_pending_at: min(request.updated_at),
      last_attempted_at: max(request.last_attempted_at)
    })
    |> repo.all()
  end

  @spec pending_count(keyword()) :: non_neg_integer()
  def pending_count(opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)

    repo.one(
      from request in Request,
        where: request.status in ["pending", "processing", "failed"],
        where: request.applied_revision < request.revision,
        select: count(request.id)
    )
  end

  @spec normalize_type(preference_type() | String.t()) ::
          {:ok, preference_type()} | {:error, :unsupported_preference_type}
  def normalize_type(type) when type in @types, do: {:ok, type}

  def normalize_type(type) when is_binary(type) do
    Enum.find(@types, &(Atom.to_string(&1) == type))
    |> case do
      nil -> {:error, :unsupported_preference_type}
      type -> {:ok, type}
    end
  end

  def normalize_type(_type), do: {:error, :unsupported_preference_type}

  defp upsert_request(owner_nickname, type, payload) do
    type_name = Atom.to_string(type)
    payload_size = payload_size(payload)

    Repo.transaction(fn ->
      case get_request(owner_nickname, type_name) do
        %Request{} = request ->
          request
          |> Request.changeset(%{
            payload: payload,
            payload_size_bytes: payload_size,
            status: "pending",
            revision: request.revision + 1,
            last_error: nil
          })
          |> Repo.update()
          |> unwrap_or_rollback()

        nil ->
          %Request{}
          |> Request.changeset(%{
            owner_nickname: owner_nickname,
            preference_type: type_name,
            payload: payload,
            payload_size_bytes: payload_size,
            status: "pending",
            revision: 1,
            applied_revision: 0,
            attempts: 0
          })
          |> Repo.insert()
          |> unwrap_or_rollback()
      end
    end)
  end

  defp apply_request(%Request{applied_revision: applied, revision: revision}, _attempt)
       when applied >= revision do
    {:ok, :already_applied}
  end

  defp apply_request(%Request{} = request, attempt) do
    target_revision = request.revision
    payload = hydrate_payload(request.preference_type, request.payload)

    case do_apply_request(request, payload, target_revision, attempt) do
      {:ok, %Request{status: "pending"}} ->
        {:error, :coalesced_update_pending}

      {:ok, _request} ->
        {:ok, :applied}

      {:error, reason} ->
        _ = mark_failed(request.id, attempt, reason)
        {:error, reason}
    end
  end

  defp do_apply_request(%Request{} = request, payload, target_revision, attempt) do
    with {:ok, request} <- mark_processing(request, attempt),
         :ok <- safe_save_preference(request.preference_type, request.owner_nickname, payload),
         {:ok, request} <- mark_applied(request.id, target_revision) do
      {:ok, request}
    end
  end

  defp mark_processing(%Request{} = request, attempt) do
    request
    |> Request.changeset(%{
      status: "processing",
      attempts: max(attempt, 1),
      last_attempted_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  defp mark_applied(request_id, target_revision) do
    case Repo.get(Request, request_id) do
      nil ->
        {:ok, nil}

      %Request{} = request ->
        status = if request.revision == target_revision, do: "applied", else: "pending"

        request
        |> Request.changeset(%{
          status: status,
          applied_revision: max(request.applied_revision, target_revision),
          last_error: nil
        })
        |> Repo.update()
    end
  end

  defp mark_failed(request_id, attempt, reason) do
    case Repo.get(Request, request_id) do
      nil ->
        {:ok, nil}

      %Request{} = request ->
        request
        |> Request.changeset(%{
          status: "failed",
          attempts: max(attempt, 1),
          last_attempted_at: DateTime.utc_now(),
          last_error: error_reason(reason)
        })
        |> Repo.update()
    end
  end

  defp save_preference("notify_list", owner, payload), do: NotifyList.save(owner, payload)
  defp save_preference("contacts", owner, payload), do: ContactList.save(owner, payload)
  defp save_preference("nick_colors", owner, payload), do: NickColors.save(owner, payload)
  defp save_preference("highlight_words", owner, payload), do: HighlightWords.save(owner, payload)
  defp save_preference("ignore_list", owner, payload), do: IgnoreList.save(owner, payload)
  defp save_preference("perform_list", owner, payload), do: PerformList.save(owner, payload)
  defp save_preference("autojoin_list", owner, payload), do: AutoJoinList.save(owner, payload)
  defp save_preference("input_history", owner, payload), do: InputHistory.save(owner, payload)
  defp save_preference("aliases", owner, payload), do: AliasList.save(owner, payload)
  defp save_preference("custom_menus", owner, payload), do: CustomMenus.save(owner, payload)

  defp save_preference("autorespond_rules", owner, payload),
    do: AutoRespondRules.save(owner, payload)

  defp save_preference("flood_protection", owner, payload),
    do: FloodProtection.save(owner, payload)

  defp save_preference("sound_settings", owner, payload), do: SoundSettings.save(owner, payload)

  defp safe_save_preference(preference_type, owner, payload) do
    save_preference(preference_type, owner, payload)
  rescue
    error -> {:error, error}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp unwrap_or_rollback({:ok, request}), do: request
  defp unwrap_or_rollback({:error, reason}), do: Repo.rollback(reason)

  defp encode_payload(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp encode_payload(%Date{} = value), do: Date.to_iso8601(value)
  defp encode_payload(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)

  defp encode_payload(%_module{} = value) do
    value
    |> Map.from_struct()
    |> encode_payload()
  end

  defp encode_payload(value) when is_map(value) do
    Map.new(value, fn {key, value} -> {encode_key(key), encode_payload(value)} end)
  end

  defp encode_payload(value) when is_list(value), do: Enum.map(value, &encode_payload/1)
  defp encode_payload(value), do: value

  defp encode_key(key) when is_atom(key), do: Atom.to_string(key)
  defp encode_key(key), do: to_string(key)

  defp hydrate_payload(_type, payload), do: hydrate_value(nil, payload)

  defp hydrate_value(_key, value) when is_map(value) do
    Map.new(value, fn {key, value} ->
      hydrated_key = hydrate_key(key)
      {hydrated_key, hydrate_value(hydrated_key, value)}
    end)
  end

  defp hydrate_value(_key, value) when is_list(value),
    do: Enum.map(value, &hydrate_value(nil, &1))

  defp hydrate_value(key, value) when key in @enum_value_keys and is_binary(value),
    do: String.to_existing_atom(value)

  defp hydrate_value(_key, value), do: value

  defp hydrate_key(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> key
  end

  defp hydrate_key(key), do: key

  defp payload_size(payload) do
    payload
    |> Jason.encode!()
    |> byte_size()
  end

  defp error_reason(%Ecto.Changeset{}), do: "changeset_error"
  defp error_reason(%module{}), do: module |> Module.split() |> List.last()
  defp error_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp error_reason(reason) when is_binary(reason), do: reason
  defp error_reason(reason), do: inspect(reason)
end
