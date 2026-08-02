defmodule TuisEverywhere.Slides.Runtimes do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "Runtimes"

  def notes do
    """
    ## Runtimes — callback and reducer

    - two ways to structure an app on the same widgets and transports
    - callback: GenServer-shaped — handle_event/2 mutates state,
      render/2 draws it; the shortest path if OTP is home
    - reducer: Elm-shaped — update(msg, state) is the single entry
      point, subscriptions/1 declares timers and PubSub declaratively,
      commands run side effects off the loop
    - subscriptions reconcile by id: return the list, the runtime arms
      and tears down as it changes — no manual timer bookkeeping
    - this deck runs on the reducer runtime; the spinning cube coming up
      is driven by a subscription that exists only while its slide is
      active
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "Runtimes", [
      "callback — GenServer-shaped: handle_event, then render",
      "reducer — Elm-shaped: update(msg, state) + subscriptions",
      "commands and subscriptions keep side effects off the loop",
      "same widgets, same transports — pick per app",
      "this deck runs on the reducer runtime"
    ])
  end
end
