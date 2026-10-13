defmodule TuisEverywhere.Slides.Ui do
  @moduledoc """
  Shared look for the TUIs-everywhere deck: one headline style, one
  bullet style, and one layout for every slide.

  Lives next to the slides but implements no `SlidesTui.Slide`
  behaviour, so deck discovery skips it — same pattern as any helper
  module sitting inside `lib/slides/`.

  ## Sizing

  A terminal only scales text through its font size, so the slides
  scale the other way round: whatever grid the font leaves, they fill
  it. Content sits on a stage (the slide area less a margin that grows
  with it), the headline goes big once there's room for it, bullets
  wrap to their column, and figures (images, the QR, 3D, canvases) grow
  to fill their share of the stage while keeping their aspect. Only
  code keeps a fixed size. The deck needs 110×30 at least.

  ## Colours

  The palette is two hues from one family: Code BEAM magenta for the
  chrome (see `SlidesTui.Chrome`) and a lighter violet for everything
  inside a slide that needs an accent — bullet markers, prompts,
  captions, the title paint. A cyan marks names inside bullets, and the
  magenta in bold marks the one phrase a slide wants remembered.

  Every colour comes from the active `SlidesTui.Theme` at render time,
  so slides read them through the functions here rather than module
  attributes: an attribute would freeze the colour at compile time and
  miss a theme switch.
  """

  alias ExRatatui.{BigText, Layout, Style}
  alias ExRatatui.Image, as: ImageWidget
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Text.{Line, Span}
  alias ExRatatui.Widgets.{Block, Paragraph}
  alias SlidesTui.Layout, as: SlidesLayout
  alias SlidesTui.Theme

  # The longest headline in the deck. Every slide switches to the big
  # banner at the same grid size, so headlines never change size from
  # one slide to the next.
  @widest_headline 17
  @gap_cols 4
  @figure_share 45

  @typedoc """
  The right-hand side of `headline_with_figure/5`, and what draws it:

    * `{:fit, cols, rows, draw}` — grows to fill its share of the
      stage, keeping a `cols:rows` aspect in cells (a cell is about
      twice as tall as it is wide)
    * `{:fixed, cols, rows, draw}` — exactly that many cells, for text
      such as code that can't scale

  `draw` takes the figure's rect and returns `{widget, rect}` tuples.
  """
  @type figure ::
          {:fit | :fixed, pos_integer(), pos_integer(), (Rect.t() -> [{struct(), Rect.t()}])}

  @typedoc "Left-hand text: bullet items to wrap, or lines that stay as they are."
  @type text :: {:bullets, [term()]} | {:lines, [Line.t()]}

  @doc """
  The slide's working area: `area` less a margin that grows with it,
  so content keeps some air at any font size without wasting a small
  grid on padding.
  """
  def stage(%Rect{} = area) do
    mx = max(2, div(area.width, 25))
    my = max(1, div(area.height, 20))

    %Rect{
      x: area.x + mx,
      y: area.y + my,
      width: max(area.width - 2 * mx, 0),
      height: max(area.height - 2 * my, 0)
    }
  end

  @doc """
  The BigText banner every headline uses, at `size` (`:quadrant`, 4
  rows, or `:full`, 8). Accepts a plain string or a pre-built `%Line{}`
  when a slide needs per-character styles.
  """
  def headline(text, size \\ :quadrant) when is_binary(text) or is_struct(text, Line) do
    BigText.new(text, pixel_size: size, alignment: :center)
  end

  @doc "The active theme — for colours without a helper of their own."
  def theme, do: Theme.current()

  @doc "The violet accent — the deck's second hue."
  def violet, do: theme().violet

  @doc "The violet accent as a foreground style."
  def violet_style, do: %Style{fg: violet()}

  @doc "The cyan for names to look up, as a foreground style."
  def cyan_style, do: %Style{fg: theme().cyan}

  @doc "The one phrase a slide wants remembered: bold, in the chrome's magenta."
  def punch_style, do: %Style{fg: theme().accent, modifiers: [:bold]}

  @doc "Secondary text (subtitles, hints) as a foreground style."
  def subtle_style, do: %Style{fg: theme().subtle}

  @doc """
  A whole content slide in one call: headline on top, then a
  left-aligned bullet column, centered on the stage as one bundle.
  """
  def headline_with_bullets(area, text, items) when is_list(items),
    do: headline_with_text(area, text, {:bullets, items})

  @doc """
  Headline over a block of text, centered on the stage as one bundle.
  `text` is `{:bullets, items}` or `{:lines, lines}`.

  Options:

    * `:alignment` — aligns the lines inside the block (default `:left`)
    * `:banner` — `:deck` (default) sizes the headline like every other
      slide's; `:own` picks the biggest size its own text fits, for the
      bookend slides
  """
  def headline_with_text(area, headline, text, opts \\ []) do
    stage = stage(area)
    size = headline_size(stage, headline, Keyword.get(opts, :banner, :deck))
    {lines, width} = text_lines(text, stage.width, body_rows(stage, headline, size))
    {head, body} = headed(stage, headline, size, length(lines))

    paragraph = %Paragraph{text: lines, alignment: Keyword.get(opts, :alignment, :left)}
    head ++ [{paragraph, SlidesLayout.center(body, width: width)}]
  end

  @doc """
  Headline over text and a figure side by side, centered on the stage
  as one bundle. `text` is `{:bullets, items}`, `{:lines, lines}` or
  `nil` for a figure alone; `headline` may be `nil` too. See `t:figure/0`
  for the figure.

  Options:

    * `:share` — the figure's share of the stage width next to text, in
      percent. Defaults to 45; a figure narrower than its share gives
      the rest back to the text.
    * `:figure_side` — `:right` (default) or `:left`
    * `:max_height` — caps the figure at this share of the height under
      the headline, in percent. Defaults to 100.
  """
  def headline_with_figure(area, headline, text, {_kind, _cols, _rows, draw} = figure, opts \\ []) do
    stage = stage(area)
    size = headline_size(stage, headline, :deck)
    rows = body_rows(stage, headline, size)
    gap = if text, do: @gap_cols, else: 0

    {lines, text_w} =
      case text do
        nil -> {[], 0}
        text -> text_lines(text, stage.width - share_width(figure, stage, opts) - gap, rows)
      end

    max_rows = div(rows * Keyword.get(opts, :max_height, 100), 100)
    {fig_w, fig_h} = figure_size(figure, stage.width - text_w - gap, max_rows)
    {head, body} = headed(stage, headline, size, max(length(lines), fig_h))
    bundle = SlidesLayout.center(body, width: text_w + gap + fig_w)

    {text_col, fig_col} =
      case Keyword.get(opts, :figure_side, :right) do
        :right ->
          [t, _, f] =
            Layout.split(bundle, :horizontal, [{:length, text_w}, {:length, gap}, {:min, 0}])

          {t, f}

        :left ->
          [f, _, t] =
            Layout.split(bundle, :horizontal, [{:length, fig_w}, {:length, gap}, {:min, 0}])

          {t, f}
      end

    text_widgets =
      if lines == [],
        do: [],
        else: [{%Paragraph{text: lines}, SlidesLayout.center(text_col, height: length(lines))}]

    head ++ text_widgets ++ draw.(SlidesLayout.center(fig_col, width: fig_w, height: fig_h))
  end

  @doc """
  Headline on top, bullets on the left, an image on the right. The
  image is whatever `figure/2` makes of `asset`.
  """
  def headline_with_bullets_and_figure(area, text, items, asset, filename),
    do: headline_with_figure(area, text, {:bullets, items}, figure(asset, filename))

  @doc """
  Loads `priv/slides/<filename>` as an image widget, or `nil` when the
  file is missing or not an image. Call it from `mount/1` and keep the
  result in the slide state.

  Images scale up to their slot: `:fit` never grows a picture past its
  own pixels, so on a projector's big cells a 400px photo would sit
  small in a corner. The slot already has the image's aspect (see
  `figure/2`), so scaling fills it without distortion.
  """
  def load_image(filename) do
    path = Path.join(:code.priv_dir(:slides_tui), "slides/#{filename}")

    with {:ok, bytes} <- File.read(path),
         {:ok, image} <- ImageWidget.new(bytes, resize: :scale) do
      image
    else
      _ -> nil
    end
  end

  @doc """
  The figure for an image: it fills its slot at the image's own aspect,
  inside a rounded violet frame so screenshots don't bleed into the
  ground. Without the image (`nil`), a violet 16:9 box naming the file
  to drop into `priv/slides/`, so slides can be written before their
  screenshots exist.
  """
  def figure(nil, filename) do
    {:fit, 32, 9,
     fn rect ->
       box = %Block{frame() | title: " placeholder "}

       hint = %Paragraph{
         text: "drop #{filename} into priv/slides/",
         alignment: :center,
         style: subtle_style()
       }

       [{box, rect}, {hint, SlidesLayout.center(inset(rect), height: 1)}]
     end}
  end

  def figure(image, _filename) do
    {w, h} = ImageWidget.dimensions(image)
    aspect = {:fit, 2 * w, h, nil}

    {:fit, 2 * w, h,
     fn rect ->
       # The image fits inside the border at its own aspect and the
       # frame hugs whatever that leaves, so no strip of ground shows
       # between picture and border.
       %Rect{width: max_w, height: max_h} = inset(rect)
       {img_w, img_h} = figure_size(aspect, max_w, max_h)
       framed = SlidesLayout.center(rect, width: img_w + 2, height: img_h + 2)
       [{frame(), framed}, {image, inset(framed)}]
     end}
  end

  defp frame, do: %Block{borders: [:all], border_type: :rounded, border_style: violet_style()}

  defp inset(%Rect{} = rect) do
    %{
      rect
      | x: rect.x + 1,
        y: rect.y + 1,
        width: max(rect.width - 2, 0),
        height: max(rect.height - 2, 0)
    }
  end

  @doc """
  Bullet items as `Line`s — violet marker, wrapped to `width` with a
  hanging indent, a blank line between items. When the spaced-out list
  would be taller than `max_rows`, the blank lines go.

  An item is either a string, where `` `backticked` `` names (packages,
  atoms, modules) come out in cyan and a `*starred*` phrase in the bold
  magenta of `punch_style/0` (one per slide at most, or nothing stands
  out), or `{:links, urls}`, which renders
  the urls cyan and dot-separated like the closing slide. Links are
  never dim: a projector washes dim text out, and links are what the
  room copies down.
  """
  def bullet_lines(items, width \\ :infinity, max_rows \\ :infinity) do
    marker = Span.new("▪ ", style: %{violet_style() | modifiers: [:bold]})

    wrapped =
      Enum.map(items, fn item ->
        [first | rest] = wrap(spans(item), width_after(width, 2))
        [Line.new([marker | first]) | Enum.map(rest, &Line.new([Span.new("  ") | &1]))]
      end)

    spaced = wrapped |> Enum.intersperse([Line.new([])]) |> Enum.concat()
    if length(spaced) > max_rows, do: Enum.concat(wrapped), else: spaced
  end

  @doc "The on-screen width of a bullet item, markup excluded."
  def item_width(item), do: item |> spans() |> spans_width()

  defp width_after(:infinity, _taken), do: :infinity
  defp width_after(width, taken), do: max(width - taken, 1)

  defp text_lines({:bullets, items}, max_width, max_rows) do
    width = min(max_width, 2 + (items |> Enum.map(&item_width/1) |> Enum.max()))
    {bullet_lines(items, width, max_rows), width}
  end

  defp text_lines({:lines, lines}, max_width, _max_rows) do
    natural = lines |> Enum.map(&spans_width(&1.spans)) |> Enum.max()
    {lines, min(max_width, natural)}
  end

  defp spans_width(spans), do: spans |> Enum.map(&String.length(&1.content)) |> Enum.sum()

  defp share_width({:fixed, cols, _rows, _draw}, stage, _opts), do: min(cols, stage.width)

  defp share_width({:fit, _cols, _rows, _draw}, stage, opts),
    do: div(stage.width * Keyword.get(opts, :share, @figure_share), 100)

  defp figure_size({:fixed, cols, rows, _draw}, max_w, max_h),
    do: {min(cols, max_w), min(rows, max_h)}

  defp figure_size({:fit, cols, rows, _draw}, max_w, max_h) do
    h = min(max_h, div(max_w * rows, cols))
    {min(max_w, div(h * cols, rows)), h}
  end

  # The headline switches to the big banner at the same grid for every
  # slide: once the widest headline fits and the banner takes no more
  # than a fifth of the height. A bookend sizes its banner by its own
  # text instead, as long as the banner stays under a third of the height.
  defp headline_size(_stage, nil, _banner), do: nil

  defp headline_size(%Rect{width: w, height: h}, _headline, :deck)
       when w >= 8 * @widest_headline and h >= 40,
       do: :full

  defp headline_size(%Rect{width: w, height: h}, headline, :own) do
    if w >= 8 * headline_length(headline) and h >= 24, do: :full, else: :quadrant
  end

  defp headline_size(_stage, _headline, _banner), do: :quadrant

  defp headline_length(%Line{spans: spans}), do: spans_width(spans)
  defp headline_length(text), do: String.length(text)

  defp headline_rows(:full), do: 8
  defp headline_rows(:quadrant), do: 4

  defp gap_rows(%Rect{height: h}) when h >= 30, do: 2
  defp gap_rows(_stage), do: 1

  defp body_rows(stage, nil, _size), do: stage.height

  defp body_rows(stage, _headline, size),
    do: max(stage.height - headline_rows(size) - gap_rows(stage), 0)

  # A headline over a body `body_height` rows tall, centered on the
  # stage as one bundle. Returns the headline's `{widget, rect}` (none
  # for a `nil` headline) and the body rect.
  defp headed(stage, nil, _size, body_height),
    do: {[], SlidesLayout.center(stage, height: body_height)}

  defp headed(stage, text, size, body_height) do
    rows = headline_rows(size)
    gap = gap_rows(stage)
    bundle = SlidesLayout.center(stage, height: rows + gap + body_height)

    [head, _gap, body] =
      Layout.split(bundle, :vertical, [{:length, rows}, {:length, gap}, {:min, 0}])

    {[{headline(text, size), head}], body}
  end

  defp spans({:links, urls}),
    do: [Span.new(Enum.join(urls, " · "), style: cyan_style())]

  # Splitting with the captures kept leaves every marked run whole, its
  # markers still on to tell names from punches.
  defp spans(text) when is_binary(text) do
    ~r/`[^`]+`|\*[^*]+\*/
    |> Regex.split(text, include_captures: true, trim: true)
    |> Enum.map(fn
      "`" <> _ = name -> Span.new(unmark(name), style: cyan_style())
      "*" <> _ = punch -> Span.new(unmark(punch), style: punch_style())
      plain -> Span.new(plain)
    end)
  end

  defp unmark(marked), do: String.slice(marked, 1..-2//1)

  # Greedy word wrap that keeps each character's style: the spans
  # become styled graphemes, words break only at spaces, and each line
  # is stitched back into spans. A word longer than the width gets a
  # line to itself.
  defp wrap(spans, :infinity), do: [spans]

  defp wrap(spans, width) do
    {lines, current, _pending} =
      spans
      |> Enum.flat_map(fn span -> Enum.map(String.graphemes(span.content), &{&1, span.style}) end)
      |> Enum.chunk_by(fn {g, _style} -> g == " " end)
      |> Enum.reduce({[], [], []}, fn
        [{" ", _} | _] = spaces, {lines, current, _pending} ->
          {lines, current, spaces}

        word, {lines, [], _pending} ->
          {lines, word, []}

        word, {lines, current, pending} ->
          if length(current) + length(pending) + length(word) <= width,
            do: {lines, current ++ pending ++ word, []},
            else: {[current | lines], word, []}
      end)

    [current | lines]
    |> Enum.reverse()
    |> Enum.map(&restyle/1)
  end

  defp restyle(graphemes) do
    graphemes
    |> Enum.chunk_by(fn {_g, style} -> style end)
    |> Enum.map(fn [{_, style} | _] = run ->
      %Span{Span.new(Enum.map_join(run, &elem(&1, 0))) | style: style}
    end)
  end
end
