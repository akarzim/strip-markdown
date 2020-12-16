require "English"
require "logger"

# StripMarkdown is a Service for stripping out Markdown formatting, leaving just plain text.
# By default, the Service will also remove the leaders from list items (*, +, - and 1.), and the code blocks.
class StripMarkdown
  SEPARATOR = " ".freeze

  REGEX_LIST = /^(?<spaces>[ \t]*)(?<bullet>[*+-] |\d+\. )/.freeze
  REGEX_URL = /<(?<url>.*?)>/.freeze
  REGEX_HR = /^(?<rule>[-*_]{3,}\s*)$/m.freeze
  REGEX_TITLE = /^(?<title>[=-]{2,}\s*)$/m.freeze
  REGEX_FOOTNOTE = /(?<mark>\[\^\d+\])(?>(?<colon>:)(?<note>.*?\n(?>\s?(?>^ {0,4}(?>[^\n]+\n)+))?))?/m.freeze
  REGEX_INLINE_FOOTNOTE = /(?<mark>\[\^[^\]]*\])\((?<note>.+?)\)/.freeze
  REGEX_IMAGE = /(?<bang>\!\[)(?<alt>.*?)(?<sep>\][\[\(])(?<src>.*?)(?<eot>[\]\)])/.freeze
  REGEX_LINK = /(?<bot>\[)(?<alt>.*?)(?<sep>\][\[\(])(?<href>.*?)(?<eot>[\]\)])/.freeze
  REGEX_LINK_REF = /^(?<bot>\[)(?<mark>.*?)(?<colon>\]: )(?<href>(?>\S+)(?> ".*?")?\s*$)/m.freeze
  REGEX_LAZY_LINK_REF = /^(?<mark>\[\*\]: )(?<href>(?>\S+)(?> ".*?")?\s*$)/m.freeze
  REGEX_HEADER = /^(?<header>\#{1,6}\s*)/m.freeze
  # REGEX_EMPHASIS = /(?<em>[_*~]+)(?<emphased>(?:[^_*~]|(?<recurse>\g<0>))+?)\k<em>/.freeze
  REGEX_CODE_BLOCK = /(?<ticks>[`\~]{3,})(?<lang>.*?)\n(?<code>.*?)\n\k<ticks>/m.freeze
  REGEX_INLINE_CODE = /`(?<code>.+?)`/.freeze
  REGEX_EMPHASIS = /(?<em>[_*\~]+)(?<emphased>.+?)\k<em>/.freeze
  REGEX_BLOCKQUOTE = /^(?<quote>\> )/.freeze
  REGEX_NEWLINE = /\n{2,}/.freeze

  def initialize(options = {})
    @logger = options.fetch(:logger, Logger.new(STDOUT))
    @separator = options.fetch(:separator, SEPARATOR)
    @prettify = options.fetch(:prettify, false)
    @strip_code_blocks = options.fetch(:strip_code_blocks, true)
    @strip_list_leaders = options.fetch(:strip_list_leaders, true)
  end

  def self.call(input, options = {})
    new(options).call(input)
  end

  # @param input [String] a markdown string to strip
  def call(input)
    output = input.dup
    blanky_list!(output) if strip_list_leaders?
    blanky_url!(output)
    blanky_hr!(output)
    blanky_footnote!(output)
    blanky_inline_footnote!(output)
    blanky_image!(output)
    blanky_link!(output)
    blanky_lazy_link_ref!(output)
    blanky_link_ref!(output)
    blanky_title!(output)
    blanky_header!(output)
    blanky_code_block!(output)
    blanky_inline_code!(output)
    blanky_emphasis!(output)
    blanky_blockquote!(output)
    pretty_newlines!(output) if prettify?
  rescue StandardError => e
    logger.error(e)
    logger.info(input)
    false
  else
    output
  end

  private

  attr_reader :logger

  def strip_code_blocks?
    !!@strip_code_blocks
  end

  def strip_list_leaders?
    !!@strip_list_leaders
  end

  def prettify?
    !!@prettify
  end

  def separator
    prettify? ? "" : @separator
  end

  def match(label, data:)
    data[label.to_sym].to_s
  end
  alias_method :m, :match

  def blanky(label, data:)
    m(label, data: data).lines(chomp: true).map { |line| separator * line.length }.join("\n")
  end
  alias_method :b, :blanky

  # Input:
  # 1. First ordered list item
  # 2. Another item
  #   * Unordered sub-list.
  # 1. Actual numbers don't matter, just that it's a number
  #   1. Ordered sub-list
  # 4. And another item.
  #
  #    You can have properly indented paragraphs within list items. Notice the blank line above, and the leading spaces (at least one, but we'll use three here to also align the raw Markdown).
  #
  #    To have a line break without a paragraph, you will need to use two trailing spaces.
  #    Note that this line is separate, but within the same paragraph.
  #    (This is contrary to the typical GFM line break behaviour, where trailing spaces are not required.)
  #
  # * Unordered list can use asterisks
  # - Or minuses
  # + Or pluses
  #
  # Output:
  #    First ordered list item
  #    Another item
  #     Unordered sub-list.
  #    Actual numbers don't matter, just that it's a number
  #      Ordered sub-list
  #    And another item.
  #
  #    You can have properly indented paragraphs within list items. Notice the blank line above, and the leading spaces (at least one, but we'll use three here to also align the raw Markdown).
  #
  #    To have a line break without a paragraph, you will need to use two trailing spaces.⋅⋅
  #    Note that this line is separate, but within the same paragraph.⋅⋅
  #    (This is contrary to the typical GFM line break behaviour, where trailing spaces are not required.)
  #
  #   Unordered list can use asterisks
  #   Or minuses
  #   Or pluses
  def blanky_list!(input)
    input.gsub!(REGEX_LIST) { b(:spaces, data: $LAST_MATCH_INFO) + b(:bullet, data: $LAST_MATCH_INFO) }
  end

  # Input:
  # URLs and URLs in angle brackets will automatically get turned into links.
  # http://www.example.com or <http://www.example.com> and sometimes
  # example.com (but not on Github, for example).
  #
  # Output:
  # URLs and URLs in angle brackets will automatically get turned into links.
  # http://www.example.com or  http://www.example.com  and sometimes
  # example.com (but not on Github, for example).
  def blanky_url!(input)
    input.gsub!(REGEX_URL) { separator + m(:url, data: $LAST_MATCH_INFO) + separator }
  end

  # Input:
  # Alt-H1
  # ======
  #
  # Alt-H2
  # ------
  #
  # Output:
  # Alt-H1
  #
  #
  # Alt-H2
  #
  def blanky_title!(input)
    input.gsub!(REGEX_TITLE) { b(:title, data: $LAST_MATCH_INFO) + "\n" }
  end

  # Input:
  # Three or more...
  #
  # ---
  #
  # Hyphens
  #
  # ***
  #
  # Asterisks
  #
  # ___
  #
  # Underscores
  #
  # Output:
  # Three or more...
  #
  #
  #
  # Hyphens
  #
  #
  #
  # Asterisks
  #
  #
  #
  # Underscores
  def blanky_hr!(input)
    input.gsub!(REGEX_HR) { b(:rule, data: $LAST_MATCH_INFO) + "\n" }
  end

  # Input:
  # Footnotes[^1] are added in-text like so ...
  #
  # And with a matching footnote definition at the end of the document:
  #
  # [^1]:
  # Footnotes are the mind killer.
  # Footnotes are the little-death that brings total obliteration.
  # I will face my footnotes.
  #
  # [^2]: This is the first paragraph.
  #
  #     This paragraph is inside the note.
  #     It looks better if the whole paragraph
  # is indented, but it isn't required. The
  # first line is enough.
  #
  # The first line of this paragraph is not
  # indented, so it is not part of the note.
  #
  # Output:
  # Footnotes     are added in-text like so ...
  #
  # And with a matching footnote definition at the end of the document:
  #
  #
  # Footnotes are the mind killer.
  # Footnotes are the little-death that brings total obliteration.
  # I will face my footnotes.
  #
  #       This is the first paragraph.
  #
  #     This paragraph is inside the note.
  #     It looks better if the whole paragraph
  # is indented, but it isn't required. The
  # first line is enough.
  #
  # The first line of this paragraph is not
  # indented, so it is not part of the note.
  def blanky_footnote!(input)
    input.gsub!(REGEX_FOOTNOTE) do
      data = $LAST_MATCH_INFO
      b(:mark, data: data) + b(:colon, data: data) + m(:note, data: data)
    end
  end

  # Input:
  # I met Jim [^jim](My old college roommate) at the station.
  #
  # I met Jim [^](My old college roommate) at the station.
  #
  # Output:
  # I met Jim       (My old college roommate) at the station.
  #
  # I met Jim    (My old college roommate) at the station.
  def blanky_inline_footnote!(input)
    input.gsub!(REGEX_INLINE_FOOTNOTE) do
      data = $LAST_MATCH_INFO
      b(:mark, data: data) + "(" + m(:note, data: data) + ")"
    end
  end

  # Input:
  # Inline-style:
  # ![alt text](https://github.com/adam-p/markdown-here/raw/master/src/common/images/icon48.png "Logo Title Text 1")
  #
  # Reference-style:
  # ![alt text][logo]
  #
  # [logo]: https://github.com/adam-p/markdown-here/raw/master/src/common/images/icon48.png "Logo Title Text 2"
  #
  # Output:
  # Inline-style:
  #   alt text
  #
  # Reference-style:
  #   alt text
  #
  #  logo
  def blanky_image!(input)
    input.gsub!(REGEX_IMAGE) do
      data = $LAST_MATCH_INFO
      b(:bang, data: data) + m(:alt, data: data) + b(:sep, data: data) + b(:src, data: data) + b(:eot, data: data)
    end
  end

  # Input:
  # [I'm an inline-style link](https://www.google.com)
  # [I'm an inline-style link with title](https://www.google.com "Google's Homepage")
  # [I'm a reference-style link][Arbitrary case-insensitive reference text]
  # [I'm a relative reference to a repository file](../blob/master/LICENSE)
  # [You can use numbers for reference-style link definitions][1]
  # Or leave it empty and use the [link text itself].
  #
  # Output:
  #  I'm an inline-style link
  #  I'm an inline-style link with title
  #  I'm a reference-style link
  #  I'm a relative reference to a repository file
  #  You can use numbers for reference-style link definitions
  # Or leave it empty and use the [link text itself].
  def blanky_link!(input)
    input.gsub!(REGEX_LINK) do
      data = $LAST_MATCH_INFO
      b(:bot, data: data) + m(:alt, data: data) + b(:sep, data: data) + b(:href, data: data) + b(:eot, data: data)
    end
  end

  # Input:
  # Some text to show that the reference links can follow later.

  # [arbitrary case-insensitive reference text]: https://www.mozilla.org
  # [1]: http://slashdot.org
  # [link text itself]: http://www.reddit.com
  #
  # Output:
  # Some text to show that the reference links can follow later.
  #
  #  arbitrary case-insensitive reference text
  #  1
  #  link text itself
  def blanky_link_ref!(input)
    input.gsub!(REGEX_LINK_REF) do
      data = $LAST_MATCH_INFO
      b(:bot, data: data) + m(:mark, data: data) + b(:colon, data: data) + b(:href, data: data)
    end
  end

  # Input:
  # # H1
  # ## H2
  # ### H3
  # #### H4
  # ##### H5
  # ###### H6
  #
  # Output:
  #   H1
  #    H2
  #     H3
  #      H4
  #       H5
  #        H6
  def blanky_header!(input)
    input.gsub!(REGEX_HEADER) { b(:header, data: $LAST_MATCH_INFO) }
  end

  # Input:
  # Emphasis, aka italics, with *asterisks* or _underscores_.
  # Strong emphasis, aka bold, with **asterisks** or __underscores__.
  # Combined emphasis with **asterisks and _underscores_**.
  # Strikethrough uses two tildes. ~~Scratch this.~~
  #
  # Output:
  # Emphasis, aka italics, with  asterisks  or  underscores .
  # Strong emphasis, aka bold, with   asterisks   or   underscores  .
  # Combined emphasis with   asterisks and  underscores   .
  # Strikethrough uses two tildes.   Scratch this.
  def blanky_emphasis!(input)
    input.gsub!(REGEX_EMPHASIS) do
      data = $LAST_MATCH_INFO
      emphased = m(:emphased, data: data)
      recursed_emphased = blanky_emphasis(emphased) || emphased
      b(:em, data: data) + recursed_emphased + b(:em, data: data)
    end
  end

  def blanky_emphasis(input)
    blanky_emphasis!(input.dup)
  end

  # Input:
  # Some JavaScript code:
  #
  # ```javascript
  # var s = "JavaScript syntax highlighting";
  # alert(s);
  # ```
  #
  # Or maybe a bit of python ;)
  #
  # ~~~python
  # s = "Python syntax highlighting"
  # print s
  # ~~~
  #
  # And then a raw code block:
  #
  # ```
  # No language indicated, so no syntax highlighting.
  # But let's throw in a <b>tag</b>.
  # ```
  #
  # Output:
  # Some JavaScript code:
  #
  #
  #
  #
  #
  #
  # Or maybe a bit of python ;)
  #
  #
  #
  #
  #
  #
  # And then a raw code block:
  #
  #
  #
  #
  #
  def blanky_code_block!(input)
    input.gsub!(REGEX_CODE_BLOCK) do
      data = $LAST_MATCH_INFO
      ticks = b(:ticks, data: data)
      lang = b(:lang, data: data)

      if strip_code_blocks?
        prettify? ? "" : ticks + lang + "\n" + b(:code, data: data) + "\n" + ticks
      else
        ticks + lang + "\n" + m(:code, data: data) + "\n" + ticks
      end
    end
  end

  # Input:
  # Inline `code` has `back-ticks around` it.
  #
  # Output:
  # Inline        has                     it.
  def blanky_inline_code!(input)
    input.gsub!(REGEX_INLINE_CODE) do
      data = $LAST_MATCH_INFO

      if strip_code_blocks?
        prettify? ? "" : separator + b(:code, data: data) + separator
      else
        separator + m(:code, data: data) + separator
      end
    end
  end

  # Input:
  # > Blockquotes are very handy in email to emulate reply text.
  # > This line is part of the same quote.
  #
  # Quote break.
  #
  # > This is a very long line that will still be quoted properly when it wraps. Oh boy let's keep writing to make sure this is long enough to actually wrap for everyone. Oh, you can *put* **Markdown** into a blockquote.
  #
  # Output:
  #   Blockquotes are very handy in email to emulate reply text.
  #   This line is part of the same quote.
  #
  # Quote break.
  #
  #   This is a very long line that will still be quoted properly when it wraps. Oh boy let's keep writing to make sure this is long enough to actually wrap for everyone. Oh, you can  put    Markdown   into a blockquote.
  def blanky_blockquote!(input)
    input.gsub!(REGEX_BLOCKQUOTE) { b(:quote, data: $LAST_MATCH_INFO) }
  end

  # Input:
  # This is my text and [this is my link][*]. I'll define
  # the url for that link under the paragraph.
  #
  # [*]: http://brettterpstra.com
  #
  # I can use [multiple][*] lazy links in [a paragraph][*],
  # and then just define them in order below it.
  #
  # [*]: https://gist.github.com/ttscoff/7059952
  # [*]: http://blog.bignerdranch.com/4044-rock-heads/
  #
  # Output:
  # This is my text and  this is my link    . I'll define
  # the url for that link under the paragraph.
  #
  #
  # I can use  multiple     lazy links in  a paragraph    ,
  # and then just define them in order below it.
  #
  #
  #
  #
  def blanky_lazy_link_ref!(input)
    input.gsub!(REGEX_LAZY_LINK_REF) do
      data = $LAST_MATCH_INFO
      b(:mark, data: data) + b(:href, data: data)
    end
  end

  def pretty_newlines!(input)
    input.gsub(REGEX_NEWLINE, "\n\n")
  end
end
