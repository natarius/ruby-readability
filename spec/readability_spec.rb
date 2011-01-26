require File.expand_path(File.join(File.dirname(__FILE__), "spec_helper"))

describe Readability do
  before do
    @simple_html_fixture = Nokogiri::HTML <<-HTML
      <html>
        <head>
          <title>title!</title>
        </head>
        <body class='comment'>
          <div>
            <p class='comment'>a comment</p>
            <div class='comment' id='body'>real content</div>
            <div id="contains_blockquote"><blockquote>something in a table</blockquote></div>
          </div>
        </body>
      </html>
    HTML
  end

  describe "transformMisusedDivsIntoParagraphs" do
    before do
      @doc = Readability::Document.new(@simple_html_fixture, nil, nil)
      @doc.transform_misused_divs_into_paragraphs!
    end

    it "should transform divs containing no block elements into <p>s" do
      @doc.document.css("#body").first.name.should == "p"
    end

    it "should not transform divs that contain block elements" do
      @doc.document.css("#contains_blockquote").first.name.should == "div"
    end
  end

  describe "score_node" do
    before do
      @html = Nokogiri::HTML <<-HTML
        <html>
          <body>
            <div id='elem1'>
              <p>some content</p>
            </div>
            <th id='elem2'>
              <p>some other content</p>
            </th>
          </body>
        </html>
      HTML

      @doc = Readability::Document.new(@html, nil, nil)
      @elem1 = @doc.document.css("#elem1").first
      @elem2 = @doc.document.css("#elem2").first
    end

    it "should like <div>s more than <th>s" do
      @doc.score_node(@elem1)[:content_score].should > @doc.score_node(@elem2)[:content_score]
    end

    it "should like classes like text more than classes like comment" do
      @elem2.name = "div"
      @doc.score_node(@elem1)[:content_score].should == @doc.score_node(@elem2)[:content_score]
      @elem1['class'] = "text"
      @elem2['class'] = "comment"
      @doc.score_node(@elem1)[:content_score].should > @doc.score_node(@elem2)[:content_score]
    end
  end

  describe "remove_unlikely_candidates!" do
    before do
      @doc = Readability::Document.new(@simple_html_fixture, nil, nil)
      @doc.remove_unlikely_candidates!
    end

    it "should remove things that have class comment" do
      @doc.document.inner_html.should_not =~ /a comment/
    end

    it "should not remove body tags" do
      @doc.document.inner_html.should =~ /<\/body>/
    end

    it "should not remove things with class comment and id body" do
      @doc.document.inner_html.should =~ /real content/
    end
  end

  describe "score_paragraphs" do
    before(:each) do
      @html = Nokogiri::HTML <<-HTML
        <html>
          <head>
            <title>title!</title>
          </head>
          <body id="body">
            <div id="div1">
              <div id="div2">
                <p id="some_comment">a comment</p>
              </div>
              <p id="some_text">some text</p>
            </div>
            <div id="div3">
              <p id="some_text2">some more text</p>
            </div>
          </body>
        </html>
      HTML

      @doc = Readability::Document.new(@html, nil, nil)
      @candidates = @doc.score_paragraphs(0)
    end

    it "should score elements in the document" do
      @candidates.values.length.should == 4
    end

    it "should prefer the body in this particular example" do
      @candidates.values.sort { |a, b|
        b[:content_score] <=> a[:content_score]
      }.first[:elem][:id].should == "body"
    end
  end

  describe "the cant_read.html fixture" do
    it "should work on the cant_read.html fixture with some allowed tags" do
      allowed_tags = %w[div span table tr td p i strong u h1 h2 h3 h4 pre code br a]
      allowed_attributes = %w[href]
      html = File.read(File.dirname(__FILE__) + "/fixtures/cant_read.html")
      Readability::Document.new(Nokogiri::HTML(html), nil, nil, :tags => allowed_tags, :attributes => allowed_attributes).content.should match(/Can you talk a little about how you developed the looks for the/)
    end
  end

  describe "general functionality" do
    before do
      @doc = Readability::Document.new(Nokogiri::HTML("<html><head><title>title!</title></head><body><div><p>Some content</p></div></body>"), nil, nil, :min_text_length => 0, :retry_length => 1)
    end

    it "should return the main page content" do
      @doc.content.should match("Some content")
    end
  end

  describe "ignoring sidebars" do
    before do
      @doc = Readability::Document.new(Nokogiri::HTML("<html><head><title>title!</title></head><body><div><p>Some content</p></div><div class='sidebar'><p>sidebar<p></div></body>"), nil, nil, :min_text_length => 0, :retry_length => 1)
    end

    it "should not return the sidebar" do
      @doc.content.should_not match("sidebar")
    end
  end

  describe "outputs good stuff for known documents" do
    before do
      @html_files = Dir.glob(File.dirname(__FILE__) + "/fixtures/samples/*.html")
      @samples = @html_files.map {|filename| File.basename(filename, '.html') }
    end

    it "should output expected fragments of text" do

      checks = 0
      @samples.each do |sample|
        html = File.read(File.dirname(__FILE__) + "/fixtures/samples/#{sample}.html")
        doc = Readability::Document.new(Nokogiri::HTML(html), nil, nil).content

        load "fixtures/samples/#{sample}-fragments.rb"
        puts "testing #{sample}..."

        $required_fragments.each do |required_text|
          doc.should include(required_text)
          checks += 1
        end

        $excluded_fragments.each do |text_to_avoid|
          doc.should_not include(text_to_avoid)
          checks += 1
        end
      end
      puts "Performed #{checks} checks."
    end
  end

  describe "handles vimeo.com videos" do

    before(:each) do
      FakeWeb.register_uri(:get, 'http://vimeo.com/10365005',
                           :response => File.read("spec/fixtures/vimeo.com.html"))
      @uri = URI.parse("http://vimeo.com/10365005")
      @content = Readability::Document.new(Nokogiri::HTML(open('http://vimeo.com/10365005')), @uri.host, @uri.request_uri).content
    end

    it "should extract the video from the page" do
      @content.should include("<iframe src=\"http://player.vimeo.com/video/10365005\"")
    end

  end

end
