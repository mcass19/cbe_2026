defmodule LobbyTuiWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use LobbyTuiWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @page_title "TUIs everywhere — Code BEAM Europe 2026"
  @source_url "https://github.com/mcass19/cbe_2026/tree/main/lobby_tui"
  @privacy_url "https://github.com/mcass19/cbe_2026/blob/main/lobby_tui/docs/PRIVACY.md"

  @doc """
  Renders the app layout: the shared title row, the page content, the
  data-transparency footer, and flash messages.

  Both pages — the join screen and the room — are HTML chrome around an
  embedded ratatui canvas, so they should read as one terminal window
  rather than two related screens. Each used to carry its own copy of
  the title row and the footer, and the two copies had drifted: different
  titles, different type scale, different padding. They live here now,
  and both pages call this function.

  The generated marketing header (logo, framework links, version badge)
  is still gone; this is the app's own chrome, not the framework's.

  Only two things vary per page. `:class` sets the outer shell, because
  the pages have genuinely different scroll semantics — the join screen
  scrolls through a hundred-odd avatars, while the room must never
  scroll, since the theatre sizes itself to the remaining space.
  `:actions` adds page-specific links beside `[source]`; the room uses it
  for the leave link. Everything else is fixed on purpose: the title and
  the footer are identity, not configuration.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

      <Layouts.app flash={@flash} id="lobby-shell" class="h-dvh overflow-hidden flex flex-col gap-2 p-2">
        <:actions>
          <.link href={~p"/leave"} method="delete">[leave]</.link>
        </:actions>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :id, :string, default: nil, doc: "optional DOM id for the outer shell"

  attr :class, :string,
    default: "min-h-dvh p-4 flex flex-col gap-2",
    doc: "outer shell classes; override for pages that must not scroll"

  slot :actions, doc: "page-specific links, rendered to the left of [source]"
  slot :inner_block, required: true

  def app(assigns) do
    assigns = assign(assigns, title: @page_title, source_url: @source_url)

    ~H"""
    <div id={@id} class={@class}>
      <header
        id="page-header"
        class="shrink-0 flex flex-col gap-1 sm:flex-row sm:items-baseline sm:justify-between"
      >
        <h1 class="text-base sm:text-xl font-bold tracking-widest text-[var(--tui-accent)]">
          {@title}
        </h1>
        <nav class="flex items-center gap-3 text-sm">
          {render_slot(@actions)}
          <a href={@source_url} target="_blank" class="text-[var(--tui-accent)] hover:underline">
            [source]
          </a>
        </nav>
      </header>

      {render_slot(@inner_block)}

      <.data_notice />
    </div>
    <.flash_group flash={@flash} />
    """
  end

  @doc """
  The data-transparency notice pinned to the bottom of the page.

  `mt-auto` pins it on the join screen, whose content does not fill the
  viewport, and is inert in the room, where the theatre already takes the
  slack via `flex-1`. One class serves both layouts.
  """
  def data_notice(assigns) do
    assigns = assign(assigns, privacy_url: @privacy_url)

    ~H"""
    <footer
      id="data-notice"
      class="shrink-0 mt-auto pt-1 text-center text-[11px] leading-tight text-[var(--tui-dim)] border-t border-[var(--tui-border)]"
    >
      Everything here lives in memory (ETS via Ash). You disappear when you disconnect.
      Messages are wiped when the server restarts. Please don't post personal information.
      <a href={@privacy_url} target="_blank" class="underline text-[var(--tui-accent-2)]">
        Privacy note.
      </a>
    </footer>
    """
  end

  @doc """
  The shared page title. Exposed so the root layout and tests agree on one
  string.

  Named `shared_title/0` rather than `page_title/0` because `root.html.heex`
  is compiled into this module and already reads `assigns[:page_title]` for
  the per-page `<title>` override — two different things that should not
  look alike at the call site.
  """
  def shared_title, do: @page_title

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
