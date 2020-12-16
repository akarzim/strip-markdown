require "test_helper"

describe StripMarkdown do
  subject { stripmkd.call(input) }

  describe "default behaviour" do
    let(:stripmkd) { StripMarkdown.new(separator: "␠") }

    describe "blanky list" do
      let(:input) do
        <<~MKD
          1. First ordered list item
          2. Another item
            * Unordered sub-list.
          1. Actual numbers don't matter, just that it's a number
            1. Ordered sub-list
          4. And another item.

             You can have properly indented paragraphs within list items. Notice the blank line above, and the leading spaces (at least one, but we'll use three here to also align the raw Markdown).

             To have a line break without a paragraph, you will need to use two trailing spaces.
             Note that this line is separate, but within the same paragraph.
             (This is contrary to the typical GFM line break behaviour, where trailing spaces are not required.)

          * Unordered list can use asterisks
          - Or minuses
          + Or pluses
        MKD
      end

      it "must replace bullets" do
        _(subject).must_equal <<~MKD
          ␠␠␠First ordered list item
          ␠␠␠Another item
          ␠␠␠␠Unordered sub-list.
          ␠␠␠Actual numbers don't matter, just that it's a number
          ␠␠␠␠␠Ordered sub-list
          ␠␠␠And another item.

             You can have properly indented paragraphs within list items. Notice the blank line above, and the leading spaces (at least one, but we'll use three here to also align the raw Markdown).

             To have a line break without a paragraph, you will need to use two trailing spaces.
             Note that this line is separate, but within the same paragraph.
             (This is contrary to the typical GFM line break behaviour, where trailing spaces are not required.)

          ␠␠Unordered list can use asterisks
          ␠␠Or minuses
          ␠␠Or pluses
        MKD
      end
    end

    describe "blanky URL" do
      let(:input) do
        <<~MKD
          URLs and URLs in angle brackets will automatically get turned into links.
          http://www.example.com or <http://www.example.com> and sometimes
          example.com (but not on Github, for example).
        MKD
      end

      it "must replace delimitors" do
        _(subject).must_equal <<~MKD
          URLs and URLs in angle brackets will automatically get turned into links.
          http://www.example.com or ␠http://www.example.com␠ and sometimes
          example.com (but not on Github, for example).
        MKD
      end
    end

    describe "blanky title" do
      let(:input) do
        <<~MKD
          Alt-H1
          ======

          Alt-H2
          ------
        MKD
      end

      it "must replace underines" do
        _(subject).must_equal <<~MKD
          Alt-H1
          ␠␠␠␠␠␠

          Alt-H2
          ␠␠␠␠␠␠
        MKD
      end
    end

    describe "blanky horizontal rule" do
      let(:input) do
        <<~MKD
          Three or more...

          ---

          Hyphens

          ***

          Asterisks

          ___

          Underscores
        MKD
      end

      it "must replace rules" do
        _(subject).must_equal <<~MKD
          Three or more...

          ␠␠␠

          Hyphens

          ␠␠␠

          Asterisks

          ␠␠␠

          Underscores
        MKD
      end
    end

    describe "blanky footnote" do
      let(:input) do
        <<~MKD
          Footnotes[^1] are added in-text like so ...

          And with a matching footnote definition at the end of the document:

          [^1]:
          Footnotes are the mind killer.
          Footnotes are the little-death that brings total obliteration.
          I will face my footnotes.

          [^2]: This is the first paragraph.

              This paragraph is inside the note.
              It looks better if the whole paragraph
          is indented, but it isn't required. The
          first line is enough.

          The first line of this paragraph is not
          indented, so it is not part of the note.
        MKD
      end

      it "must replace marks" do
        _(subject).must_equal <<~MKD
          Footnotes␠␠␠␠ are added in-text like so ...

          And with a matching footnote definition at the end of the document:

          ␠␠␠␠␠
          Footnotes are the mind killer.
          Footnotes are the little-death that brings total obliteration.
          I will face my footnotes.

          ␠␠␠␠␠ This is the first paragraph.

              This paragraph is inside the note.
              It looks better if the whole paragraph
          is indented, but it isn't required. The
          first line is enough.

          The first line of this paragraph is not
          indented, so it is not part of the note.
        MKD
      end
    end

    describe "blanky inline footnote" do
      let(:input) do
        <<~MKD
          I met Jim [^jim](My old college roommate) at the station.

          I met Jim [^](My old college roommate) at the station.
        MKD
      end

      it "must replace marks" do
        _(subject).must_equal <<~MKD
          I met Jim ␠␠␠␠␠␠(My old college roommate) at the station.

          I met Jim ␠␠␠(My old college roommate) at the station.
        MKD
      end
    end

    describe "blanky code block" do
      let(:input) do
        <<~MKD
          ~~~yaml
          # A Savoir pour le frontmatter:
          titre: Attention pas de « : » dans le titre
          description: Elle sera utilisée dans le meta
          preview_size: Nombre de paragraphes de l'aperçu dans le flux tronqué
          related: Array of Array avec titre custom et lien de l'article. Utiliser nil utilisera le titre de l'article d'origine
          ~~~

          ```ruby
          puts "Le code sera formaté correctement."
          ```
        MKD
      end

      it "must replace block demimiters" do
        _(subject).must_equal <<~MKD
          ␠␠␠␠␠␠␠
          ␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠
          ␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠
          ␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠
          ␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠
          ␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠
          ␠␠␠

          ␠␠␠␠␠␠␠
          ␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠␠
          ␠␠␠
        MKD
      end
    end
  end
end
