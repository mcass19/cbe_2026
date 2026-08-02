defmodule SlidesTui.Test.Fixtures.DeckInteractive.Stopper do
  @moduledoc "Stops the deck on any non-nav event."
  use SlidesTui.Slide

  alias ExRatatui.Widgets.Paragraph

  def render(_state, area), do: [{%Paragraph{text: "stop"}, area}]

  def handle_event(_event, state), do: {:stop, state}
end
