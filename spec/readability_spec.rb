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

  describe 'dealing with iso-8859-1' do
    before(:each) do
      file = File.open('spec/fixtures/folha.html', 'r')
      @content = file.read
    end

    it "should return the main page content" do
      Readability::Document.new(Nokogiri::HTML(@content, nil, 'ISO-8859'),nil,nil).content.unpack("C*").pack("U*")  .should == "<div><div>\n <p>\n COLABORA\303\207\303\203O PARA A FOLHA\n </p>\n <p>\n A Anvisa (Ag\303\252ncia Nacional de Vigil\303\242ncia Sanit\303\241ria) interditou o lote do ch\303\241 de erva doce da marca Dr. Oetker. A medida foi publicada no \"Di\303\241rio Oficial da Uni\303\243o\" na quarta-feira (26).\n </p>\n <p>\n Segundo a Vigil\303\242ncia Sanit\303\241ria, o lote L160T02 do produto --data de validade 01/12/2011-- apresentou resultado insatisfat\303\263rio no ensaio de pesquisa para mat\303\251rias macrosc\303\263picas e microsc\303\263picas que detectou a presen\303\247a de p\303\252lo de roedor e fragmentos de inseto.\n </p>\n <p>\n A interdi\303\247\303\243o cautelar vale pelo per\303\255odo de 90 dias ap\303\263s a data de publica\303\247\303\243o. Durante esse tempo, o produto interditado n\303\243o deve ser consumido e nem comercializado. As pessoas que j\303\241 adquiriram o produto do lote suspenso devem interromper o consumo.\n </p>\n</div></div>"
    end
  end

  describe 'dealing with utf-8' do
    before do
      @doc = Readability::Document.new(Nokogiri::HTML("<html><head><title>title!</title></head><body><div><p>Açougue, espátula, Vovô, çáóéãà</p></div></body>", nil, 'UTF-8'), nil, nil, :min_text_length => 0, :retry_length => 1)
    end

    it 'should return the main page content' do
      @doc.content.should match("Açougue, espátula, Vovô, çáóéãà")
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

  describe "handles portal o dia" do

    it "should extract the news and images from the page" do
      url = "http://portalodia.com/noticias/piaui/mais-de-um-veiculo-e-roubado-por-dia-na-capital-102189.html"
      FakeWeb.register_uri(:get, url,
                           :response => File.read("spec/fixtures/portalodia_photo.html"))
      @uri = URI.parse(url)
      @parsed_page = Readability::Document.new(Nokogiri::HTML(open(url)),
      @uri.host, @uri.request_uri)
      @content = @parsed_page.content

      @content.should == "<p>\"A gente fica se sentindo impotente. N\303\243o sabe o que fazer\". Foi esse o sentimento que a jornalista Vanessa Viana teve ao saber que o seu carro havia sido levado por um assaltante no bairro Bela Vista, zona Sul de Teresina, no \303\272ltimo dia 29. Assim como Vanessa, de acordo com um levantamento do Comando de Policiamento da Capital da Pol\303\255cia Militar, outras 45 pessoas<br>tiveram seus ve\303\255culos (carros e motocicletas) roubados ou furtados em janeiro deste ano. O n\303\272mero representa uma m\303\251dia de 1,5 ve\303\255culos levados por bandidos diariamente na capital no per\303\255odo.</p><p>\"Eu tinha comprado o carro h\303\241 quatro meses apenas. Quando me falaram, na delegacia, que o assaltante j\303\241 era procurado pela pol\303\255cia, fiquei assustada. Afinal, uma pessoa que podia estar presa levou meu carro\", afirma Vanessa Viana. A jornalista conta que o carro, um Uno Mille novo, na noite em que foi roubado estava estacionado em uma rua no bairro Bela Vista em Teresina. No local, o seu cunhado que dirigia o ve\303\255culo participava de um encontro de jovens da Igreja do bairro.</p><p><img src=\"/media/uploads/filebrowser/moto1.jpg\" alt=\"\" width=\"510\" height=\"339\"></p>"
    end

    it "should extract the news from the page" do
      FakeWeb.register_uri(:get, 'http://portalodia.com/noticias/mundo/homem-chama-a-policia-porque-nao-quer-fazer-sexo-com-a-mulher-100984.html',
                           :response => File.read("spec/fixtures/portalodia.com.html"))
      @uri = URI.parse("http://portalodia.com/noticias/mundo/homem-chama-a-policia-porque-nao-quer-fazer-sexo-com-a-mulher-100984.html")
      @parsed_page = Readability::Document.new(Nokogiri::HTML(open('http://portalodia.com/noticias/mundo/homem-chama-a-policia-porque-nao-quer-fazer-sexo-com-a-mulher-100984.html')),
      @uri.host, @uri.request_uri)
      @content = @parsed_page.content

      @content.should == "<p>A pol\303\255cia alem\303\243 informou nesta ter\303\247a-feira que recebeu um chamado no m\303\255nimo inusitado. Um homem da cidade de Waiblingen, distrito de Stuttgart, ligou para os policiais porque n\303\243o queria mais fazer sexo com sua mulher.</p><p>De acordo com ele, apesar de recusar seguidamente as ofertas, ela continua insistindo e n\303\243o o\302\240deixa dormir. O casal, que tem dois filhos, est\303\241 junto h\303\241 18 anos, mas j\303\241 n\303\243o dorme na mesma cama h\303\241 quatro.\302\240</p><p>Embora o caso seja curioso, n\303\243o \303\251 in\303\251dito no pa\303\255s europeu. Em 2006, a pol\303\255cia de Aachen, oeste da Alemanha, foi acionada por uma mulher que acusava o marido de n\303\243o cumprir suas obriga\303\247\303\265es conjugais.</p><p>Na ocasi\303\243o, ap\303\263s meses sem nenhum contato f\303\255sico, ela acordou no meio da madrugada e exigiu que o c\303\264njuge satisfizesse suas necessidades sexuais. Frustrada por ter seu pedido negado, ela acionou os agentes, que nada puderam fazer.</p><p>O porta voz da pol\303\255cia, Paul Kemen, explicou \303\240 \303\251poca que os policiais n\303\243o se sentiram capazes de resolver o caso. \"O que eles puderam fazer foi abrir uma ocorr\303\252ncia para o caso de uma poss\303\255vel interven\303\247\303\243o futura\", disse.\302\240</p>"
    end
  end
end
