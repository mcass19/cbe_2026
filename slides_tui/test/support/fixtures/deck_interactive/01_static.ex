defmodule SlidesTui.Test.Fixtures.DeckInteractive.Static do
  @moduledoc "Static slide with speaker notes — exercises the presenter view."
  use SlidesTui.Slide

  alias ExRatatui.Widgets.Paragraph

  def notes, do: "## Static\n\nThese are the notes."

  def render(_state, area), do: [{%Paragraph{text: "static"}, area}]
end
