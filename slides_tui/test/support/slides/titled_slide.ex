defmodule SlidesTui.Test.TitledSlide do
  @moduledoc "Stateless titled slide — used by Host.render tests."
  use SlidesTui.Slide

  alias ExRatatui.Widgets.Paragraph

  def title, do: "Hello"
  def render(_state, area), do: [{%Paragraph{text: "body"}, area}]
end
