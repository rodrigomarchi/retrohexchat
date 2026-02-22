defmodule RetroHexChatWeb.LandingController do
  @moduledoc """
  Serves the public landing pages.

  These are standard Phoenix controller actions (not LiveView) for optimal SEO
  and performance — no WebSocket, no LiveView JS overhead.
  """
  use RetroHexChatWeb, :controller

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    render(conn, :index, active_page: :home)
  end

  @spec about(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def about(conn, _params) do
    render(conn, :about,
      active_page: :about,
      page_title: "About Retro Hex Chat — Why self-hosted chat matters",
      page_description:
        "Understand the problem with centralized chat platforms and how Retro Hex Chat gives you back control of your community."
    )
  end

  @spec how_it_works(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def how_it_works(conn, _params) do
    render(conn, :how_it_works,
      active_page: :how_it_works,
      page_title: "How Retro Hex Chat Works — Server, P2P, Privacy & Security",
      page_description:
        "Learn how Retro Hex Chat works: self-hosted server architecture, WebRTC P2P calls, privacy protections, and security layers."
    )
  end

  @spec features(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def features(conn, _params) do
    render(conn, :features,
      active_page: :features,
      page_title: "Features — Retro Hex Chat",
      page_description:
        "Real-time chat, public and private channels, P2P voice and video calls, server administration, and IRC-style commands."
    )
  end

  @spec privacy(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def privacy(conn, _params) do
    render(conn, :privacy,
      active_page: :privacy,
      page_title: "Privacy Comparison — Retro Hex Chat vs Discord, Slack & Telegram",
      page_description:
        "Side-by-side privacy comparison: data ownership, call routing, message access, AI training, and source code transparency."
    )
  end

  @spec install(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def install(conn, _params) do
    render(conn, :install,
      active_page: :install,
      page_title: "Install Retro Hex Chat — Three steps to your own server",
      page_description:
        "Clone, setup, and run your own Retro Hex Chat server in three simple steps. System requirements and getting started guide."
    )
  end

  @spec community(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def community(conn, _params) do
    render(conn, :community,
      active_page: :community,
      page_title: "Open Source & Community — Retro Hex Chat",
      page_description:
        "Retro Hex Chat is MIT-licensed open source software. Contribute, star, share, or sponsor the project on GitHub."
    )
  end

  @spec faq(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def faq(conn, _params) do
    render(conn, :faq,
      active_page: :faq,
      page_title: "FAQ — Retro Hex Chat",
      page_description:
        "Frequently asked questions about Retro Hex Chat: P2P calls, server requirements, security, contributing, and more."
    )
  end
end
