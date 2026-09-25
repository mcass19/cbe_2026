defmodule TuisEverywhere.Slides.Ui do
  @moduledoc """
  Shared look for the TUIs-everywhere deck: one headline style, one
  bullet style, and one shape for the demo interstitials.

  Lives next to the slides but implements no `SlidesTui.Slide`
  behaviour, so deck discovery skips it — same pattern as any helper
  module sitting inside `lib/slides/`.

  The palette is two hues from one family: Code BEAM magenta for the
  chrome (see `SlidesTui.Chrome`) and a lighter violet for everything
  inside a slide that needs an accent — bullet markers, prompts,
  captions, the title paint. A cyan marks names inside bullets.

  Every colour comes from the active `SlidesTui.Theme` at render time,
  so slides read them through the functions here rather than module
  attributes: an attribute would freeze the colour at compile time and
  miss a theme switch.
  """

  alias ExRatatui.{BigText, Layout, Style}
  alias ExRatatui.Image, as: ImageWidget
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.{Block, Paragraph}
  alias SlidesTui.Layout, as: SlidesLayout
  alias SlidesTui.Theme

  @headline_height 4
  @gap 2

  @doc """
  The quadrant-size BigText banner every headline uses. Accepts a plain
  string or a pre-built `%Line{}` when a slide needs per-character styles.
  """
  def headline(text) when is_binary(text) or is_struct(text, Line) do
    BigText.new(text, pixel_size: :quadrant, alignment: :center)
  end

  @doc "The active theme — for colours without a helper of their own."
  def theme, do: Theme.current()

  @doc "The violet accent — the deck's second hue."
  def violet, do: theme().violet

  @doc "The violet accent as a foreground style."
  def violet_style, do: %Style{fg: violet()}

  @doc "The cyan for names to look up, as a foreground style."
  def cyan_style, do: %Style{fg: theme().cyan}

  @doc "Secondary text (subtitles, hints) as a foreground style."
  def subtle_style, do: %Style{fg: theme().subtle}

  @doc """
  A whole content slide in one call: BigText headline on top, a gap,
  then a left-aligned bullet column centered in the remaining space.
  Returns the `{widget, rect}` list `render/2` expects.
  """
  def headline_with_bullets(area, text, items) when is_list(items) do
    lines = bullet_lines(items)
    width = 2 + (items |> Enum.map(&item_width/1) |> Enum.max())

    bundle = SlidesLayout.center(area, height: @headline_height + @gap + length(lines))

    [head, _gap, body] =
      Layout.split(bundle, :vertical, [
        {:length, @headline_height},
        {:length, @gap},
        {:min, 0}
      ])

    [
      {headline(text), head},
      {%Paragraph{text: lines}, SlidesLayout.center(body, width: width)}
    ]
  end

  @doc """
  The demo interstitial: a big `Demo` banner with a centered caption
  underneath. The caption is one string per line.
  """
  def demo(area, caption_lines) when is_list(caption_lines) do
    bundle =
      SlidesLayout.center(area, height: @headline_height + @gap + length(caption_lines))

    [head, _gap, body] =
      Layout.split(bundle, :vertical, [
        {:length, @headline_height},
        {:length, @gap},
        {:min, 0}
      ])

    caption = %Paragraph{
      text: Enum.join(caption_lines, "\n"),
      alignment: :center,
      style: violet_style()
    }

    [{headline("Demo"), head}, {caption, body}]
  end

  @doc """
  Headline on top, bullets on the left, a figure on the right. The
  figure is whatever `figure/3` returns for `asset` — an image when the
  file is there, a placeholder box when it is not — so slides can be
  written before their screenshots exist.
  """
  def headline_with_bullets_and_figure(area, text, items, asset, filename) do
    lines = bullet_lines(items)
    bullets_height = length(lines)
    figure_width = 70
    figure_height = 24
    body_height = max(bullets_height, figure_height)

    bundle = SlidesLayout.center(area, width: 150, height: @headline_height + @gap + body_height)

    [head, _gap, body] =
      Layout.split(bundle, :vertical, [
        {:length, @headline_height},
        {:length, @gap},
        {:min, 0}
      ])

    [text_col, _mid, figure_col] =
      Layout.split(body, :horizontal, [{:min, 0}, {:length, 4}, {:length, figure_width}])

    [
      {headline(text), head},
      {%Paragraph{text: lines}, SlidesLayout.center(text_col, height: bullets_height)}
      | figure(asset, filename, SlidesLayout.center(figure_col, height: figure_height))
    ]
  end

  @doc """
  Loads `priv/slides/<filename>` as an image widget, or `nil` when the
  file is missing or not an image. Call it from `mount/1` and keep the
  result in the slide state.
  """
  def load_image(filename) do
    path = Path.join(:code.priv_dir(:slides_tui), "slides/#{filename}")

    with {:ok, bytes} <- File.read(path),
         {:ok, image} <- ImageWidget.new(bytes, resize: :fit) do
      image
    else
      _ -> nil
    end
  end

  @doc """
  The figure for a slot: the image when we have one, otherwise a dashed
  violet box naming the file to drop into `priv/slides/`.
  """
  def figure(nil, filename, rect) do
    box = %Block{
      borders: [:all],
      border_type: :rounded,
      border_style: violet_style(),
      title: " placeholder "
    }

    hint = %Paragraph{
      text: "drop #{filename} into priv/slides/",
      alignment: :center,
      style: subtle_style()
    }

    inner = %{rect | x: rect.x + 1, y: rect.y + 1, width: rect.width - 2, height: rect.height - 2}
    [{box, rect}, {hint, SlidesLayout.center(inner, height: 1)}]
  end

  def figure(image, _filename, rect), do: [{image, rect}]

  @doc """
  Bullet items as `Line`s — violet marker, blank line between items.

  An item is either a string, where `` `backticked` `` names (packages,
  atoms, modules) come out in cyan, or `{:links, urls}`, which renders
  the urls cyan and dot-separated like the closing slide. Links are
  never dim: a projector washes dim text out, and links are what the
  room copies down.
  """
  def bullet_lines(items) do
    items
    |> Enum.map(fn item ->
      Line.new([Span.new("▪ ", style: %{violet_style() | modifiers: [:bold]}) | spans(item)])
    end)
    |> Enum.intersperse(Line.new([]))
  end

  @doc "The on-screen width of a bullet item, markup excluded."
  def item_width(item), do: item |> spans() |> Enum.map(&String.length(&1.content)) |> Enum.sum()

  defp spans({:links, urls}),
    do: [Span.new(Enum.join(urls, " · "), style: cyan_style())]

  # Splitting on backticks leaves the marked names at the odd positions.
  defp spans(text) when is_binary(text) do
    text
    |> String.split("`")
    |> Enum.with_index()
    |> Enum.reject(fn {part, _i} -> part == "" end)
    |> Enum.map(fn
      {part, i} when rem(i, 2) == 1 -> Span.new(part, style: cyan_style())
      {part, _i} -> Span.new(part)
    end)
  end
end
