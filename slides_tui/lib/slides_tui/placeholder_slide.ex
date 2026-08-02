defmodule SlidesTui.PlaceholderSlide do
  @moduledoc """
  Rendered by the host when slide discovery returns no slides. Shows
  a friendly hint about where to put slide modules.
  """
  use SlidesTui.Slide

  alias ExRatatui.Style
  alias ExRatatui.Widgets.Paragraph

  @message """
  No slides found.

  Add a module to lib/slides/ and restart the deck.
  See SlidesTui.Slide for the behaviour.

  Press q to quit.
  """

  def render(_state, area) do
    [
      {%Paragraph{
         text: @message,
         alignment: :center,
         style: %Style{modifiers: [:dim]}
       }, area}
    ]
  end
end
