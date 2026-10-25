defmodule RetroHexChat.Commands.Handlers.Cs do
  @moduledoc "Handler for /cs (ChanServ commands)"
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards, only: [require_channel: 1, require_operator: 3]

  alias RetroHexChat.Channels.Categories
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.Archive
  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Timestamp
  alias RetroHexChat.Locales
  alias RetroHexChat.Services.{ChanServ, Queries}

  use RetroHexChat.Commands.Handler,
    name: "cs",
    category: :advanced,
    syntax: dgettext("commands", "/cs <subcommand> [args]"),
    summary:
      dgettext("commands", "Manage channel registration and access lists through ChanServ."),
    description:
      dgettext(
        "commands",
        "Manage channel registration and access lists through ChanServ.\nSubcommands: register, drop, info, archive on|off, language <code|none>, category <name|none>, sop/aop/vop add|del|list, help. Must be in a channel.\nAccess hierarchy: SOP (super-operator) > AOP (auto-operator) > VOP (auto-voice).\nRegister requires channel operator. Drop, archive, language and category require being the channel founder."
      ),
    examples: [
      dgettext("commands", "/cs register"),
      dgettext("commands", "/cs drop"),
      dgettext("commands", "/cs info"),
      dgettext("commands", "/cs archive on"),
      dgettext("commands", "/cs language pt_BR"),
      dgettext("commands", "/cs category news"),
      dgettext("commands", "/cs sop add nick"),
      dgettext("commands", "/cs aop del nick"),
      dgettext("commands", "/cs vop list")
    ],
    parameters: [
      %Parameter{
        name: "subcommand",
        required: true,
        type: :text,
        position: 0,
        description:
          dgettext(
            "commands",
            "Subcommand: register, drop, info, archive, language, category, sop, aop, vop"
          )
      },
      %Parameter{
        name: "args",
        required: false,
        type: :text,
        position: 1,
        description: dgettext("commands", "Subcommand arguments")
      }
    ],
    subcommands: [
      %{name: "register", description: dgettext("commands", "Register the current channel")},
      %{name: "drop", description: dgettext("commands", "Drop channel registration")},
      %{name: "info", description: dgettext("commands", "View channel registration info")},
      %{
        name: "archive",
        description: dgettext("commands", "Publish the channel's public archive (on|off)")
      },
      %{
        name: "language",
        description: dgettext("commands", "Set the language the channel is spoken in (code|none)")
      },
      %{
        name: "category",
        description:
          dgettext(
            "commands",
            "Set what the channel is about, such as news or games (name|none)"
          )
      },
      %{name: "sop", description: dgettext("commands", "Manage super-operator access list")},
      %{name: "aop", description: dgettext("commands", "Manage auto-operator access list")},
      %{name: "vop", description: dgettext("commands", "Manage auto-voice access list")},
      %{name: "help", description: dgettext("commands", "Show ChanServ help")}
    ]

  @access_levels ~w(sop aop vop)

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error,
     dgettext(
       "commands",
       "Usage: /cs <register|drop|info|archive|language|category|sop|aop|vop|help> [args]"
     )}
  end

  # Registering makes the channel yours for good, so it is for whoever already runs it — the
  # same bar as the Registration tab in Channel Central, which offers it to operators only.
  def execute(["register" | _], context) do
    with {:ok, _channel} <- require_channel(context),
         :ok <-
           require_operator(
             context,
             context.active_channel,
             chanserv_message(
               dgettext("commands", "You must be a channel operator to register the channel")
             )
           ) do
      call_register(context.active_channel, context.nickname, server(context))
    end
  end

  def execute(["drop" | _], context) do
    call_drop(context.active_channel, context.nickname, server(context))
  end

  def execute(["info" | _], context) do
    call_info(context.active_channel, server(context))
  end

  def execute(["archive", state | _], context) when state in ~w(on off) do
    with {:ok, _channel} <- require_channel(context) do
      call_set_archive(context.active_channel, context.nickname, state == "on")
    end
  end

  def execute(["archive" | _], context) do
    with {:ok, _channel} <- require_channel(context) do
      call_archive_status(context.active_channel)
    end
  end

  def execute(["language", code | _], context) do
    with {:ok, _channel} <- require_channel(context) do
      call_set_language(context.active_channel, context.nickname, code)
    end
  end

  def execute(["language" | _], context) do
    with {:ok, _channel} <- require_channel(context) do
      call_language_status(context.active_channel)
    end
  end

  def execute(["category", code | _], context) do
    with {:ok, _channel} <- require_channel(context) do
      call_set_category(context.active_channel, context.nickname, code)
    end
  end

  def execute(["category" | _], context) do
    with {:ok, _channel} <- require_channel(context) do
      call_category_status(context.active_channel)
    end
  end

  def execute([level, "add", target | _], context) when level in @access_levels do
    call_manage_access(
      context.active_channel,
      :add,
      level,
      target,
      context.nickname,
      server(context)
    )
  end

  def execute([level, "del", target | _], context) when level in @access_levels do
    call_manage_access(
      context.active_channel,
      :remove,
      level,
      target,
      context.nickname,
      server(context)
    )
  end

  def execute([level, "list" | _], context) when level in @access_levels do
    call_list_access(context.active_channel, level, server(context))
  end

  def execute([level | _], _context) when level in @access_levels do
    {:error, "Usage: /cs #{level} <add|del|list> [nick]"}
  end

  def execute([subcmd | _], _context) do
    {:error, "Unknown ChanServ command: #{subcmd}. Try /cs help"}
  end

  # ── Private helpers ─────────────────────────────────────────

  defp service_message(message), do: {:ok, :system, %{content: chanserv_message(message)}}

  defp chanserv_message(message) do
    dgettext("commands", "[ChanServ] %{message}", message: message)
  end

  defp server(context), do: Map.get(context, :chan_serv, ChanServ)

  defp call_register(channel, founder, server) do
    case ChanServ.register(channel, founder, server) do
      {:ok, msg} ->
        service_message(msg)

      {:error, msg} ->
        {:error, chanserv_message(msg)}
    end
  end

  defp call_drop(channel, nickname, server) do
    case ChanServ.drop(channel, nickname, server) do
      {:ok, msg} ->
        service_message(msg)

      {:error, msg} ->
        {:error, chanserv_message(msg)}
    end
  end

  defp call_info(channel, server) do
    case ChanServ.info(channel, server) do
      {:ok, info} ->
        text =
          dgettext(
            "commands",
            "[ChanServ] %{name}: founder=%{founder}, registered=%{registered_at}",
            name: info.name,
            founder: info.founder,
            registered_at: Timestamp.format(info.registered_at)
          )

        {:ok, :system, %{content: text}}

      {:error, msg} ->
        {:error, chanserv_message(msg)}
    end
  end

  defp call_set_archive(channel, nickname, enabled?) do
    case Server.set_public_archive(channel, nickname, enabled?) do
      :ok ->
        {:ok, :system, %{content: archive_switched(channel, enabled?)}}

      {:error, msg} ->
        {:error, chanserv_message(msg)}
    end
  end

  defp call_archive_status(channel) do
    text =
      Enum.join(
        [
          archive_state(channel, Archive.published?(channel)),
          dgettext("commands", "Usage: /cs archive <on|off>")
        ],
        "\n"
      )

    {:ok, :system, %{content: text}}
  end

  # Switching it on is the moment "from now on" means something; asked later,
  # the archive has simply been on since whenever that was.
  defp archive_switched(channel, true) do
    dgettext(
      "commands",
      "[ChanServ] The public archive of %{channel} is on: what is said from now on is published.",
      channel: channel
    )
  end

  defp archive_switched(channel, false), do: archive_state(channel, false)

  defp archive_state(channel, true) do
    dgettext("commands", "[ChanServ] The public archive of %{channel} is on.", channel: channel)
  end

  defp archive_state(channel, false) do
    dgettext("commands", "[ChanServ] The public archive of %{channel} is off.", channel: channel)
  end

  # `none` and `off` clear it, as the archive switch reads `off`; anything else
  # has to name a language the chat speaks, written however the reader likes.
  defp call_set_language(channel, nickname, code) when code in ~w(none off) do
    case Server.set_locale(channel, nickname, nil) do
      :ok ->
        {:ok, :system,
         %{
           content:
             dgettext("commands", "[ChanServ] %{channel} no longer has a language.",
               channel: channel
             )
         }}

      {:error, msg} ->
        {:error, chanserv_message(msg)}
    end
  end

  defp call_set_language(channel, nickname, code) do
    with {:ok, locale} <- language_code(code),
         :ok <- Server.set_locale(channel, nickname, locale) do
      {:ok, :system, %{content: language_state(channel, locale)}}
    else
      {:error, msg} -> {:error, chanserv_message(msg)}
    end
  end

  defp call_language_status(channel) do
    locale =
      case Queries.find_registered_channel(channel) do
        %{locale: locale} -> locale
        nil -> nil
      end

    text =
      Enum.join(
        [
          language_state(channel, locale),
          dgettext("commands", "Usage: /cs language <code|none>"),
          dgettext("commands", "Languages: %{codes}", codes: Enum.join(Locales.codes(), ", "))
        ],
        "\n"
      )

    {:ok, :system, %{content: text}}
  end

  defp language_code(code) do
    case Locales.normalize(code) do
      nil ->
        {:error,
         dgettext("commands", "Unknown language: %{code}. Languages: %{codes}",
           code: code,
           codes: Enum.join(Locales.codes(), ", ")
         )}

      locale ->
        {:ok, locale}
    end
  end

  defp language_state(channel, nil) do
    dgettext("commands", "[ChanServ] %{channel} has no language set.", channel: channel)
  end

  defp language_state(channel, locale) do
    dgettext("commands", "[ChanServ] %{channel} is spoken in %{language} (%{code}).",
      channel: channel,
      language: Locales.label(locale),
      code: locale
    )
  end

  defp call_set_category(channel, nickname, code) when code in ~w(none off) do
    case Server.set_category(channel, nickname, nil) do
      :ok ->
        {:ok, :system,
         %{
           content:
             dgettext("commands", "[ChanServ] %{channel} no longer has a category.",
               channel: channel
             )
         }}

      {:error, msg} ->
        {:error, chanserv_message(msg)}
    end
  end

  defp call_set_category(channel, nickname, code) do
    case Categories.normalize(code) do
      nil ->
        {:error,
         dgettext("commands", "[ChanServ] Unknown category: %{code}. Categories: %{codes}",
           code: code,
           codes: Enum.join(Categories.codes(), ", ")
         )}

      category ->
        case Server.set_category(channel, nickname, category) do
          :ok -> {:ok, :system, %{content: category_state(channel, category)}}
          {:error, msg} -> {:error, chanserv_message(msg)}
        end
    end
  end

  defp call_category_status(channel) do
    category =
      case Queries.find_registered_channel(channel) do
        %{category: category} -> category
        nil -> nil
      end

    text =
      Enum.join(
        [
          category_state(channel, category),
          dgettext("commands", "Usage: /cs category <name|none>"),
          dgettext("commands", "Categories: %{codes}", codes: Enum.join(Categories.codes(), ", "))
        ],
        "\n"
      )

    {:ok, :system, %{content: text}}
  end

  defp category_state(channel, nil) do
    dgettext("commands", "[ChanServ] %{channel} has no category set.", channel: channel)
  end

  defp category_state(channel, category) do
    dgettext("commands", "[ChanServ] %{channel} is about %{category} (%{code}).",
      channel: channel,
      category: Categories.label(category),
      code: category
    )
  end

  defp call_manage_access(channel, action, level, target, requester, server) do
    case ChanServ.manage_access(channel, action, level, target, requester, server) do
      {:ok, msg} ->
        service_message(msg)

      {:error, msg} ->
        {:error, chanserv_message(msg)}
    end
  end

  defp call_list_access(channel, level, server) do
    case ChanServ.info(channel, server) do
      {:ok, _} ->
        {:ok, :system, %{content: format_access_list(channel, level)}}

      {:error, msg} ->
        {:error, chanserv_message(msg)}
    end
  end

  defp format_access_list(channel, level) do
    entries =
      channel
      |> Queries.list_access()
      |> Enum.filter(&(&1.level == level))

    [
      dgettext("commands", "[ChanServ] Access list for %{channel} (%{level})",
        channel: channel,
        level: level
      )
      | format_access_lines(entries)
    ]
    |> Enum.join("\n")
  end

  defp format_access_lines([]), do: [dgettext("commands", "  (empty)")]

  defp format_access_lines(entries) do
    Enum.map(entries, fn entry ->
      dgettext("commands", "  %{nickname} [%{level}] (added by %{added_by})",
        nickname: entry.nickname,
        level: entry.level,
        added_by: entry.added_by
      )
    end)
  end
end
