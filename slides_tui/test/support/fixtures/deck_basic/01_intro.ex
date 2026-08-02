defmodule SlidesTui.Test.Fixtures.DeckBasic.Intro do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Widgets.Paragraph

  def render(_state, area), do: [{%Paragraph{text: "intro"}, area}]
end
