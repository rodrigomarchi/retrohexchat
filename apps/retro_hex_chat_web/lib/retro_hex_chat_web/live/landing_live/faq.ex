defmodule RetroHexChatWeb.LandingLive.Faq do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Accordion

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.SEO

  @typedoc "One answer fragment: plain text, or text the page emphasises."
  @type answer_part :: String.t() | {:strong, String.t()}

  @typedoc "One question, as the page draws it and as the structured data states it."
  @type entry :: %{
          window: String.t(),
          group: String.t(),
          question: String.t(),
          answer: [answer_part()]
        }

  # The questions, once. The accordion renders from this and so does the
  # `FAQPage` structured data, because a second hand-kept copy is how the two
  # drift and the rich result starts quoting an answer the page no longer gives.
  #
  # Msgids are `dgettext_noop` and translated at render, not at compile time:
  # a module attribute evaluated while compiling freezes every answer in
  # whichever locale happened to compile the file.
  @entries [
    %{
      window: "getting-started",
      group: "faq-start",
      question: dgettext_noop("landing", "What is P2P?"),
      answer: [
        dgettext_noop(
          "landing",
          "P2P (peer-to-peer) means data goes directly between users without passing through the chat server. Retro Hex Chat uses WebRTC P2P for private calls, file transfers, and multiplayer game sessions. The server helps users find each other (signaling), then the private session runs browser-to-browser when the network allows it."
        )
      ]
    },
    %{
      window: "getting-started",
      group: "faq-start",
      question: dgettext_noop("landing", "What are Spaces?"),
      answer: [
        dgettext_noop(
          "landing",
          "Spaces are shared 8-bit map views attached to channels and direct messages. You choose an avatar, move around the same conversation, and see chat messages as in-map bubbles. They do not create a separate chat room; they visualize the conversation you are already in."
        )
      ]
    },
    %{
      window: "getting-started",
      group: "faq-start",
      question: dgettext_noop("landing", "Are channel conferences P2P?"),
      answer: [
        dgettext_noop(
          "landing",
          "No. Private 1:1 calls are P2P, but channel conferences use a self-hosted SFU/room server. Each browser sends media to your server, and your server routes streams to the other participants. That makes group calls practical while keeping infrastructure under your control."
        )
      ]
    },
    %{
      window: "getting-started",
      group: "faq-start",
      question: dgettext_noop("landing", "Do I need to run my own server?"),
      answer: [
        dgettext_noop(
          "landing",
          "Not necessarily! You can create an account on any public server. Running your own server is for those who want total control."
        )
      ]
    },
    %{
      window: "getting-started",
      group: "faq-start",
      question: dgettext_noop("landing", "Is it free?"),
      answer: [
        dgettext_noop(
          "landing",
          "Yes, the software is 100% free and open source (MIT). If you run your own server, you only pay for hosting (a $5/month VPS is enough)."
        )
      ]
    },
    %{
      window: "getting-started",
      group: "faq-start",
      question: dgettext_noop("landing", "How is it different from Discord?"),
      answer: [
        dgettext_noop(
          "landing",
          "On Discord, your data lives on their servers and your communities can be removed at any time. On Retro Hex Chat, you control your server and database, private sessions can run directly between users via P2P, channel conferences run on your own infrastructure, and the code is open source — you can audit every line."
        )
      ]
    },
    %{
      window: "getting-started",
      group: "faq-start",
      question: dgettext_noop("landing", "What if my server goes down?"),
      answer: [
        dgettext_noop(
          "landing",
          "Your data lives in your PostgreSQL database. Regular backups mean you can restore on any new machine. Active private P2P sessions may keep working through brief server interruptions because they connect directly between users; chat, Spaces, and channel conferences depend on the server and reconnect when it returns."
        )
      ]
    },
    %{
      window: "getting-started",
      group: "faq-start",
      question: dgettext_noop("landing", "Is it secure?"),
      answer: [
        dgettext_noop(
          "landing",
          "Yes. Server connections use HTTPS/WSS with TLS encryption. Private P2P calls use WebRTC transport encryption, channel conferences use WebRTC media through your self-hosted room server, and passwords are hashed with bcrypt. The code is open source, so anyone can audit it."
        )
      ]
    },
    %{
      window: "technical-community",
      group: "faq-tech",
      question: dgettext_noop("landing", "What technologies are used?"),
      answer: [
        dgettext_noop(
          "landing",
          "Elixir and Phoenix on the backend, PostgreSQL for data, Phoenix Channels for real-time messaging, Vanilla JS and Canvas for Spaces, WebRTC for private P2P sessions, and a self-hosted SFU for channel conferences. Everything is open source."
        )
      ]
    },
    %{
      window: "technical-community",
      group: "faq-tech",
      question: dgettext_noop("landing", "How can I contribute?"),
      answer: [
        dgettext_noop(
          "landing",
          "Check out our contributing guide on GitHub! We accept code, documentation, translation, design, testing, and bug reports. Issues marked “good first issue” are a great place to start."
        )
      ]
    },
    %{
      window: "technical-community",
      group: "faq-tech",
      question: dgettext_noop("landing", "How can I support financially?"),
      answer: [
        dgettext_noop(
          "landing",
          "Through GitHub Sponsors. Every contribution, no matter how small, helps keep the project alive and in active development."
        )
      ]
    },
    %{
      window: "technical-community",
      group: "faq-tech",
      question: dgettext_noop("landing", "Does it work on mobile?"),
      answer: [
        dgettext_noop(
          "landing",
          "Yes! The interface is responsive and works on any modern browser. Native apps are planned for the future."
        )
      ]
    },
    %{
      window: "technical-community",
      group: "faq-tech",
      question: dgettext_noop("landing", "Can I use it for my company or team?"),
      answer: [
        dgettext_noop(
          "landing",
          "Absolutely. Run a private server, create invite-only channels, and keep all your team’s communication on your own infrastructure. No per-seat pricing, no message limits."
        )
      ]
    },
    %{
      window: "technical-community",
      group: "faq-tech",
      question: dgettext_noop("landing", "How do sessions work?"),
      answer: [
        dgettext_noop("landing", "Each nickname can only have"),
        {:strong, dgettext_noop("landing", "one active session")},
        dgettext_noop(
          "landing",
          "at a time. If you connect from another browser or tab, the previous session is automatically disconnected. If your connection drops, the client attempts to reconnect up to 10 times with exponential backoff. After all attempts fail, the session expires and you’re redirected to the login screen. Registered nicknames are protected by password — only the owner can connect with that nick."
        )
      ]
    }
  ]

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_page: :faq,
       windows: [
         %{id: "intro", label: dgettext("landing", "FAQ"), icon: :icon_question},
         %{
           id: "getting-started",
           label: dgettext("landing", "Getting Started"),
           icon: :icon_question
         },
         %{
           id: "technical-community",
           label: dgettext("landing", "Technical & Community"),
           icon: :icon_code
         }
       ],
       canonical_path: "/faq",
       page_title: dgettext("landing", "FAQ — Retro Hex Chat"),
       page_description:
         dgettext(
           "landing",
           "Frequently asked questions about Retro Hex Chat: Spaces, private P2P calls, channel conferences, server requirements, security, contributing, and more."
         ),
       json_ld: [
         SEO.breadcrumb_json_ld([
           {dgettext("landing", "Home"), "/"},
           {dgettext("landing", "FAQ"), "/faq"}
         ]),
         SEO.faq_page_json_ld(
           Enum.map(entries(), &{&1.question, answer_text(&1)}),
           "/faq"
         )
       ]
     )}
  end

  @doc """
  The questions belonging to one window, translated.
  """
  @spec entries(String.t() | nil) :: [entry()]
  def entries(window \\ nil) do
    @entries
    |> Enum.filter(&(is_nil(window) or &1.window == window))
    |> Enum.map(fn entry ->
      %{entry | question: translate(entry.question), answer: Enum.map(entry.answer, &part/1)}
    end)
  end

  @doc """
  An entry's answer as one plain string, for structured data.
  """
  @spec answer_text(entry()) :: String.t()
  def answer_text(%{answer: parts}) do
    parts
    |> Enum.map(fn
      {:strong, text} -> text
      text -> text
    end)
    |> Enum.join(" ")
  end

  attr :part, :any, required: true

  defp answer_part(%{part: {:strong, text}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <strong>{@text}</strong>
    """
  end

  defp answer_part(assigns) do
    ~H"""
    {@part}
    """
  end

  defp part({:strong, msgid}), do: {:strong, translate(msgid)}
  defp part(msgid), do: translate(msgid)

  defp translate(msgid), do: Gettext.dgettext(RetroHexChatWeb.Gettext, "landing", msgid)
end
