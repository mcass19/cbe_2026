defmodule SlidesTui.Test.Fixtures.DeckBasic.Overview do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Widgets.Paragraph

  def render(_state, area), do: [{%Paragraph{text: "overview"}, area}]
end
