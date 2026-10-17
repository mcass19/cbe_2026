defmodule TuisEverywhere.Slides.Transports do
  @moduledoc false
  use SlidesTui.Slide

  alias TuisEverywhere.Slides.Ui

  def title, do: "Transports"

  def notes do
    """
    - two questions: where do the bytes go, where do the events come from. answer those and the app runs anywhere
    - :local: this terminal
    - :ssh: the node is the server, otp's own daemon, no sshd
    - :distributed: app on a node with no terminal and no nif. we attach and render on our side
    - nerves: all three, one firmware
    - custom: contract is small, the guide has a tcp one in ~95 lines
    - punchline: the app never changes. transport is an option, not an architecture
    """
  end

  def render(_state, area) do
    Ui.headline_with_bullets(area, "One app, any door", [
      "`:local`: this terminal",
      "`:ssh`: the BEAM is the server",
      "`:distributed`: attach from another node",
      "`Nerves`: all three, one firmware",
      "`custom`: bytes out, events in",
      "*the app never changes*"
    ])
  end
end
