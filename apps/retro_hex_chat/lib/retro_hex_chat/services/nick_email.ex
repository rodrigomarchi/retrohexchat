defmodule RetroHexChat.Services.NickEmail do
  @moduledoc """
  The optional address on a registered nickname, and the way back in.

  Registering is still a nickname and a password. An address is added later, by
  the owner, and nothing shows it to anybody else: no query selects it for
  another person and nothing joins on it. What it buys is recovery — without
  one, a forgotten password means losing the nickname until it expires.

  Three rules shape the whole module:

    * **Optional means optional.** The unique index is partial, so one address
      belongs to one nickname while every nickname without one is free to have
      none.
    * **A reset tells nobody anything.** `request_reset/2` answers `:ok` for a
      nickname that does not exist, one with no address and one that never
      confirmed theirs, because any other answer is a way to read the register.
    * **A token opens one door.** The salt goes into the key derivation, so the
      link that confirms an address cannot be spent on changing a password, and
      the hash is all that is stored — a leaked database row cannot be replayed.

  Building a URL is a web concern and this app has no routes, so the caller
  passes a function that turns a token into a link.

  Lives beside `NickServ` rather than inside it: that module is the identity
  service and already carries registration, identification, ghosting and the
  identified-set GenServer. Recovery is its own story and shares none of that
  state.
  """
  use Gettext, backend: RetroHexChat.Gettext

  import Ecto.Query

  require Logger

  alias RetroHexChat.ChangesetErrors
  alias RetroHexChat.Jobs.MailWorker
  alias RetroHexChat.Mailer
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.SignedToken

  @confirm_salt "nick_email_confirm"
  @reset_salt "nick_password_reset"

  # A day is long enough for somebody who read the message the next morning, and
  # short enough that a link left in an inbox stops working.
  @max_age 24 * 60 * 60

  # A second link cannot be asked for until the first has had time to arrive.
  # Without it the form is a way to send somebody else mail repeatedly.
  @debounce_seconds 300

  @type url_fun :: (String.t() -> String.t())

  @doc "How long a link is good for."
  @spec max_age() :: pos_integer()
  def max_age, do: @max_age

  @doc "How long before another link can be asked for."
  @spec debounce_seconds() :: pos_integer()
  def debounce_seconds, do: @debounce_seconds

  @doc """
  Attaches `address` to `nickname` and sends the link that confirms it.

  The address is stored unconfirmed: until the link is followed it is worth
  nothing, and in particular `request_reset/2` will not send to it. That is what
  stops somebody typing an address they do not own and receiving a reset for it.
  """
  @spec set_email(String.t(), String.t(), url_fun()) :: :ok | {:error, String.t()}
  def set_email(nickname, address, url_fun) do
    with {:ok, nick} <- fetch(nickname),
         {:ok, token, hash} <- mint(nickname, @confirm_salt),
         {:ok, _row} <- store_email(nick, address, hash) do
      enqueue(
        address,
        dgettext("services", "Confirm your RetroHexChat address"),
        dgettext(
          "services",
          "Somebody added this address to the RetroHexChat nickname %{nickname}. Open this link to confirm it:\n\n%{link}\n\nIf this was not you, ignore this message — nothing has changed and the address will stay unconfirmed.",
          nickname: nickname,
          link: url_fun.(token)
        )
      )
    end
  end

  @doc "Forgets the address, and the pending link with it."
  @spec remove_email(String.t()) :: :ok | {:error, String.t()}
  def remove_email(nickname) do
    with {:ok, nick} <- fetch(nickname) do
      nick
      |> RegisteredNick.email_changeset(%{
        email: nil,
        email_verified_at: nil,
        email_token_hash: nil,
        email_token_sent_at: nil
      })
      |> Repo.update()
      |> case do
        {:ok, _row} -> :ok
        {:error, changeset} -> {:error, error_message(changeset)}
      end
    end
  end

  @doc "Confirms the address the token was minted for, and spends the token."
  @spec verify_email(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, :expired | :invalid}
  def verify_email(token, opts \\ []) do
    with {:ok, nickname} <- open(token, @confirm_salt, opts),
         {:ok, nick} <- match_token(nickname, token) do
      nick
      # The sent-at stamp goes with the token. It exists to space out sends,
      # and a link that has been followed is a send that finished — leaving it
      # behind would make "forgot my password" refuse for five minutes to
      # somebody who had just confirmed their address.
      |> RegisteredNick.email_changeset(%{
        email_verified_at: DateTime.utc_now(),
        email_token_hash: nil,
        email_token_sent_at: nil
      })
      |> Repo.update()
      |> case do
        {:ok, row} -> {:ok, row.nickname}
        {:error, _changeset} -> {:error, :invalid}
      end
    end
  end

  @doc """
  Sends a reset link, if there is anywhere to send one.

  Always `:ok`. A nickname that does not exist, one with no address and one that
  never confirmed theirs are all answered identically and on purpose: this is
  the one place where saying what happened would let anybody read the register
  one nickname at a time.
  """
  @spec request_reset(String.t(), url_fun()) :: :ok
  def request_reset(nickname, url_fun) do
    with {:ok, nick} <- fetch(nickname),
         true <- confirmed?(nick),
         true <- past_debounce?(nick),
         {:ok, token, hash} <- mint(nick.nickname, @reset_salt),
         {:ok, _row} <- store_token(nick, hash) do
      enqueue(
        nick.email,
        dgettext("services", "Reset your RetroHexChat password"),
        dgettext(
          "services",
          "Somebody asked to reset the password for the RetroHexChat nickname %{nickname}. Open this link to choose a new one:\n\n%{link}\n\nIf this was not you, ignore this message — your password has not changed.",
          nickname: nick.nickname,
          link: url_fun.(token)
        )
      )
    end

    :ok
  end

  @doc "Sets a new password from a reset link, and spends the token."
  @spec reset_password(String.t(), String.t(), keyword()) ::
          :ok | {:error, :expired | :invalid | String.t()}
  def reset_password(token, password, opts \\ []) do
    with {:ok, nickname} <- open(token, @reset_salt, opts),
         {:ok, nick} <- match_token(nickname, token) do
      nick
      |> RegisteredNick.password_reset_changeset(%{password: password})
      |> Repo.update()
      |> case do
        {:ok, _row} -> :ok
        {:error, changeset} -> {:error, error_message(changeset)}
      end
    end
  end

  @doc """
  Whether a reset link is still good, without spending it.

  The page that asks for a new password needs this: offering a form that the
  submit will refuse is worse than saying up front that the link is dead.
  """
  @spec reset_token_valid?(String.t(), keyword()) :: boolean()
  def reset_token_valid?(token, opts \\ []) do
    match?(
      {:ok, _nick},
      with({:ok, nickname} <- open(token, @reset_salt, opts)) do
        match_token(nickname, token)
      end
    )
  end

  @doc "Whether this server can send anything at all."
  @spec enabled?() :: boolean()
  def enabled?, do: Mailer.configured?() and Mailer.from() != nil

  @doc """
  The address on `nickname` and whether it has been confirmed.

  One query for the one question the account window asks — an unconfirmed
  address still has to be shown, because otherwise the person who typed it sees
  an empty field and types it again.
  """
  @spec address(String.t()) :: {String.t() | nil, boolean()}
  def address(nickname) do
    case fetch(nickname) do
      {:ok, nick} -> {nick.email, confirmed?(nick)}
      _missing -> {nil, false}
    end
  end

  @doc "The confirmed address on `nickname`, or `nil`."
  @spec confirmed_email(String.t()) :: String.t() | nil
  def confirmed_email(nickname) do
    case fetch(nickname) do
      {:ok, nick} -> if confirmed?(nick), do: nick.email
      _missing -> nil
    end
  end

  @doc "Every nickname with a confirmed address whose last visit falls in the window."
  @spec confirmed_between(DateTime.t(), DateTime.t()) :: [RegisteredNick.t()]
  def confirmed_between(from, to) do
    RegisteredNick
    |> where([n], not is_nil(n.email) and not is_nil(n.email_verified_at))
    |> where([n], n.last_seen_at >= ^from and n.last_seen_at < ^to)
    |> Repo.all()
  end

  @doc """
  Hands one message to the queue.

  Not sent here: SMTP takes as long as the other server takes, and the caller is
  usually a LiveView with somebody waiting in front of it.
  """
  @spec enqueue(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def enqueue(address, subject, body) do
    %{to: address, subject: subject, body: body}
    |> MailWorker.new()
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.warning("Could not queue mail to #{obscure(address)}: #{inspect(reason)}")
        {:error, dgettext("services", "The message could not be sent")}
    end
  end

  @doc "Sends one message, or says the server cannot."
  @spec deliver(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def deliver(address, subject, body) do
    case Mailer.from() do
      nil ->
        {:error, dgettext("services", "This server cannot send e-mail")}

      from ->
        Swoosh.Email.new()
        |> Swoosh.Email.to(address)
        |> Swoosh.Email.from(from)
        |> Swoosh.Email.subject(subject)
        |> Swoosh.Email.text_body(body)
        |> Mailer.deliver()
        |> case do
          {:ok, _metadata} ->
            :ok

          {:error, reason} ->
            Logger.warning("Could not send mail to #{obscure(address)}: #{inspect(reason)}")
            {:error, dgettext("services", "The message could not be sent")}
        end
    end
  end

  defp fetch(nickname) when is_binary(nickname) do
    case Repo.get_by(RegisteredNick, nickname: nickname) do
      nil -> {:error, dgettext("services", "Nickname is not registered")}
      nick -> {:ok, nick}
    end
  end

  defp fetch(_nickname), do: {:error, dgettext("services", "Nickname is not registered")}

  defp store_email(nick, address, hash) do
    nick
    |> RegisteredNick.email_changeset(%{
      email: address,
      email_verified_at: nil,
      email_token_hash: hash,
      email_token_sent_at: DateTime.utc_now()
    })
    |> Repo.update()
    |> case do
      {:ok, row} -> {:ok, row}
      {:error, changeset} -> {:error, error_message(changeset)}
    end
  end

  defp store_token(nick, hash) do
    nick
    |> RegisteredNick.email_changeset(%{
      email_token_hash: hash,
      email_token_sent_at: DateTime.utc_now()
    })
    |> Repo.update()
    |> case do
      {:ok, row} -> {:ok, row}
      {:error, changeset} -> {:error, error_message(changeset)}
    end
  end

  # Signed so it cannot be forged, hashed so the stored copy cannot be replayed,
  # and bound to one salt so it cannot be spent on the other door.
  defp mint(nickname, salt) do
    token = SignedToken.sign(secret(), salt, nickname)
    {:ok, token, hash(token)}
  end

  defp open(token, salt, opts) when is_binary(token) do
    max_age = Keyword.get(opts, :max_age, @max_age)
    SignedToken.verify(secret(), salt, token, max_age: max_age)
  end

  defp open(_token, _salt, _opts), do: {:error, :invalid}

  # A signature that checks out is not enough: the row has to still be holding
  # this token. That is what makes a link single-use, and what makes removing an
  # address cancel the link already in somebody's inbox.
  defp match_token(nickname, token) do
    with {:ok, nick} <- fetch(nickname) do
      if is_binary(nick.email_token_hash) and
           Plug.Crypto.secure_compare(nick.email_token_hash, hash(token)) do
        {:ok, nick}
      else
        {:error, :invalid}
      end
    else
      _missing -> {:error, :invalid}
    end
  end

  defp confirmed?(%RegisteredNick{email: email, email_verified_at: at}),
    do: is_binary(email) and at != nil

  defp past_debounce?(%RegisteredNick{email_token_sent_at: nil}), do: true

  defp past_debounce?(%RegisteredNick{email_token_sent_at: sent_at}) do
    DateTime.diff(DateTime.utc_now(), sent_at) >= @debounce_seconds
  end

  defp hash(token), do: :sha256 |> :crypto.hash(token) |> Base.encode16(case: :lower)

  defp secret do
    Application.get_env(:retro_hex_chat, :channel_space_join_secret) ||
      raise "Missing :channel_space_join_secret configuration"
  end

  # A log line is not the place for somebody's address.
  defp obscure(address) when is_binary(address) do
    case String.split(address, "@", parts: 2) do
      [_local, domain] -> "***@" <> domain
      _other -> "***"
    end
  end

  defp error_message(changeset) do
    changeset
    |> ChangesetErrors.by_field()
    |> Enum.flat_map(fn {field, messages} -> Enum.map(messages, &"#{field} #{&1}") end)
    |> List.first()
    |> Kernel.||(dgettext("services", "Could not be saved"))
  end
end
