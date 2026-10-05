defmodule TuisEverywhere.Slides.AdvancedWidgets do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Subscription
  alias ExRatatui.ThreeD.{Camera, Light, Material, Mesh, Object, Scene, Transform}
  alias ExRatatui.Widgets.{Block, Viewport3D}
  alias SlidesTui.Theme
  alias TuisEverywhere.Slides.Ui

  @bullets [
    "`images` — Kitty / Sixel / iTerm2, halfblock fallback",
    "`3D` — lit scenes rasterized into cells",
    "`copy & paste` — bracketed paste, one event per paste",
    "`markdown & code` — syntect-highlighted, straight from strings",
    "`focus ring` + `mouse hit-testing`, an eleven-slot theme palette",
    "`custom widgets` — compose existing ones in pure Elixir, no Rust"
  ]

  def title, do: "Advanced widgets"

  def notes do
    """
    Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum.
    """
  end

  def mount(_opts), do: {:ok, %{angle: 0.0}}

  def subscriptions(_state), do: [Subscription.interval(:cube_spin, 100, :spin)]

  def handle_info(:spin, state), do: {:noreply, %{state | angle: state.angle + 0.06}}
  def handle_info(_msg, state), do: {:noreply, state}

  # The cube's box is square in pixels: twice as many columns as rows.
  def render(%{angle: angle}, area) do
    Ui.headline_with_figure(
      area,
      "Beyond text",
      {:bullets, @bullets},
      {:fit, 2, 1, &[{viewport(angle), &1}]},
      share: 40
    )
  end

  defp viewport(angle) do
    theme = Ui.theme()

    cube = %Object{
      mesh: Mesh.cube(),
      material: %Material{color: Theme.rgb(theme.accent)},
      transform: %Transform{rotation: {:euler_xyz, {angle * 0.3, angle, 0.0}}}
    }

    %Viewport3D{
      scene: %Scene{
        objects: [cube],
        # Enough ambient that the faces turned from the light stay a dark
        # magenta; at 0.2 they went near-black against the ground.
        lights: [
          Light.ambient({255, 255, 255}, 0.35),
          Light.directional({-1.0, -1.0, -1.0}, {255, 255, 255}),
          Light.point({2.0, 3.0, 2.0}, {180, 220, 255})
        ],
        # The theme's ground, so the cube floats on the slide instead
        # of sitting in a box of another colour.
        background: Theme.rgb(theme.ground)
      },
      # Close enough that the cube fills most of the box.
      camera: %Camera{position: {1.8, 1.5, 2.4}, target: {0.0, 0.0, 0.0}},
      # Real pixels on a graphics-capable terminal (Kitty protocol in
      # Ghostty, like bb_tui's robot), braille cells elsewhere. The host
      # probes the terminal on start, which pixel modes need for the
      # cell size. Pixel modes re-send the image every frame; if the
      # spin flickers on the presenting terminal, `:braille` is the
      # smooth cell-mode fallback.
      render_mode: :auto,
      block: %Block{
        borders: [:all],
        border_type: :rounded,
        border_style: Ui.violet_style()
      }
    }
  end
end
