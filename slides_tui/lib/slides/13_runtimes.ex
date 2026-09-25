defmodule TuisEverywhere.Slides.Runtimes do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "Runtimes"

  def notes do
    """
    - two ways to shape an app, same widgets, same transports. plus a third for scripts: ExRatatui.run/2 with a closure, no module at all
    - callback: genserver-shaped. handle_event mutates, render draws. shortest path if otp is home. handle_info gets anything: pubsub, tasks, plain send
    - reducer: elm-shaped. update(msg, state) single entry for events and infos, subscriptions/1 declares timers, commands run effects off the loop
    - subscriptions reconcile by id: return the list, runtime arms and tears down. change the interval and it re-arms. no timer bookkeeping
    - Command.async never crashes the runtime: a raise comes back as {:error, reason} into update. no raw Task.async in production
    - intents: any term from a handler goes to the transport. phoenix reads navigate / patch / redirect, transports without a writer drop them
    - failure semantics: render raises -> frame skipped, logged, app keeps the last screen. a handler raises -> crash, supervisor remounts fresh. child spec is transient, a clean stop stays down
    - app_opts on a daemon or listener reaches every client's mount: pubsub, repo, feature flags, no globals
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Shape of an app", [
      "`callback` — GenServer-shaped: mount, render, handle_event",
      "`reducer` — Elm-shaped: update(msg, state) + subscriptions",
      "commands and subscriptions keep side effects off the loop",
      "same widgets, same transports — pick per app",
      "this deck runs on the reducer runtime"
    ])
  end
end
