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

  describe "testing custom pages" do
    use_vcr_cassette 'pages', :record => :new_episodes

    describe "handles vimeo.com videos" do

      before(:each) do
        url = 'http://vimeo.com/10365005'
        @uri = URI.parse(url)
        response = Net::HTTP.get_response(@uri)
        @content = Readability::Document.new(Nokogiri::HTML(response.body), @uri.host, @uri.request_uri).content
      end

      it "should extract the video from the page" do
        @content.should include("<iframe src=\"http://player.vimeo.com/video/10365005\"")
      end
    end

    describe "handles portal o dia" do

      it "should extract the news and images from the page" do
        url = "http://portalodia.com/noticias/piaui/mais-de-um-veiculo-e-roubado-por-dia-na-capital-102189.html"
        @uri = URI.parse(url)
        response = Net::HTTP.get_response(@uri)

        @parsed_page = Readability::Document.new(Nokogiri::HTML(response.body), @uri.host, @uri.request_uri)
        @content = @parsed_page.content

        @content.should == "<p>\"A gente fica se sentindo impotente. N\303\243o sabe o que fazer\". Foi esse o sentimento que a jornalista Vanessa Viana teve ao saber que o seu carro havia sido levado por um assaltante no bairro Bela Vista, zona Sul de Teresina, no \303\272ltimo dia 29. Assim como Vanessa, de acordo com um levantamento do Comando de Policiamento da Capital da Pol\303\255cia Militar, outras 45 pessoas<br>tiveram seus ve\303\255culos (carros e motocicletas) roubados ou furtados em janeiro deste ano. O n\303\272mero representa uma m\303\251dia de 1,5 ve\303\255culos levados por bandidos diariamente na capital no per\303\255odo.</p><p>Segundo as estat\303\255sticas da Pol\303\255cia Militar, dos 45 ve\303\255culos roubados ou furtados, 20 eram autom\303\263veis e 25 eram motocicletas. Destes apenas 10 foram recuperados at\303\251 o in\303\255cio do m\303\252s de fevereiro. O aumento dos furtos e roubos apontado pela pol\303\255cia \303\251 confirmado pelas v\303\255timas desse tipo de crime cada vez mais comum no Estado.</p><p>\"Eu tinha comprado o carro h\303\241 quatro meses apenas. Quando me falaram, na delegacia, que o assaltante j\303\241 era procurado pela pol\303\255cia, fiquei assustada. Afinal, uma pessoa que podia estar presa levou meu carro\", afirma Vanessa Viana. A jornalista conta que o carro, um Uno Mille novo, na noite em que foi roubado estava estacionado em uma rua no bairro Bela Vista em Teresina. No local, o seu cunhado que dirigia o ve\303\255culo participava de um encontro de jovens da Igreja do bairro.</p><p><img src=\"/media/uploads/filebrowser/moto1.jpg\" alt=\"\" width=\"510\" height=\"339\"></p><p>Ao retornar ao local, foram\302\240 abordados por um homem que fingia ser flanelinha. Com uma arma apontada para sua cabe\303\247a, o cunhado de Vanessa foi obrigada a dar a chave do carro. \"O carro tinha seguro. Mas, comprei o carro com muito sacrif\303\255cio juntamente com meus pais. Meu pai \303\251 feirante, vende melancias. A gente fica \342\200\230desnorteado'. Uma coisa que voc\303\252 batalha para<br>ter, desaparece em minutos\", conta. O homem que levou o ve\303\255culo da jornalista foi preso dois dias ap\303\263s o roubo, mas j\303\241 havia vendido o ve\303\255culo por R$ 3 mil a um receptador do Maranh\303\243o.</p><p><br>Na maioria das ocorr\303\252ncias, os furtos e os roubos acontecem de forma r\303\241pida, sem que a v\303\255tima perceba a tempo de impedi-los. O comerciante Lourival Gomes conta que n\303\243o percebeu qualquer movimento suspeito no dia em que teve a Saveiro, ano<br>1995, roubada, h\303\241 um ano, no centro de Teresina. \"Fui jantar na casa da filha e em 20 minutos levaram o carro. \303\211 muito r\303\241pido e deixa a gente sem ch\303\243o\", lembra. Segundo Gomes, o ve\303\255culo n\303\243o possu\303\255a seguro.</p><p>Em 2010, conforme dadosda Polinter, delegacia especializada em roubos e furtos de cargas e ve\303\255culos, foram roubados 331 ve\303\255culos (carros e motos) e furtados 338 em todo o Estado. Ao todo, 669 ve\303\255culos, sendo que foram recuperados 512 (276 motocicletas e 236 carros), estando, ainda, em poder de bandidos 156 ve\303\255culos que n\303\243o foram localizados.</p><p><img src=\"/media/uploads/filebrowser/moto.jpg\" alt=\"\" width=\"510\" height=\"203\"></p><p>A maioria dos ve\303\255culos roubados s\303\243o levados para os estados do Maranh\303\243o, Par\303\241, Tocantins, Cear\303\241, Pernambuco e Bahia. De acordo com o delegado da Polinter, Francisco Costa, o Bareta, recentemente alguns policiais tiveram que ir ao estado do Maranh\303\243o para recuperar tr\303\252s motos roubadas em Teresina e que se encontravam circulando normalmente na cidade maranhense de Colinas. \"A fiscaliza\303\247\303\243o nas cidades do interior ainda \303\251 deficiente. Da\303\255, a facilidade desses ve\303\255culos circularem em outras cidades\", disse.</p><p><br>Quem estaciona o carro nas ruas do centro de Teresina e em algumas vias da zona Leste da cidade est\303\241 vulner\303\241vel a ser mais uma v\303\255tima desse tipo de crime. De acordo com o Comando do Policiamento da Capital, os assaltantes n\303\243o t\303\252m hora para agir, mas o per\303\255odo do final da tarde \303\251 o preferido pelos bandidos, principalmente depois do hor\303\241rio de visita quando os guardadores de j\303\241 n\303\243o est\303\243o mais por perto.</p><p><br>Segundo o coronel Jos\303\251 Fernandes de Albuquerque, o centro da cidade e a zona Leste s\303\243o as regi\303\265es de Teresina de maior \303\255ndice de roubos e furtos de ve\303\255culos. S\303\243o \303\241reas onde existe muita concentra\303\247\303\243o de pessoas e, consequentemente, de ve\303\255culos. \"Nessas regi\303\265es, o fluxo di\303\241rio de pessoas \303\251 enorme. Nas ruas \303\251 f\303\241cil constatar que motoristas estacionam o seu ve\303\255culo pela manh\303\243 e somente no final da tarde retornam para peg\303\241-lo. Nesse intervalo, os ve\303\255culos ficam \303\240 merc\303\252 dos ladr\303\265es\",<br>explicou.</p><p><img title=\"Cel. Albuquerque diz que ladr\303\265es percebem os h\303\241bitos dos motoristas (Foto: Raoni Barbosa)\" src=\"/media/uploads/filebrowser/moto2.jpg\" alt=\"Cel. Albuquerque diz que ladr\303\265es percebem os h\303\241bitos dos motoristas (Foto: Raoni Barbosa)\" width=\"510\" height=\"339\"></p><p><em>Cel. Albuquerque diz que ladr\303\265es percebem os h\303\241bitos dos motoristas (Foto: Raoni Barbosa)</em></p><p><br><strong>Motos roubadas t\303\252m destino certo: munic\303\255pios do interior do PI e MA</strong></p><p>De acordo com informa\303\247\303\265es da Polinter, nos \303\272ltimos anos t\303\252m aumentado consideravelmente o n\303\272mero de motocicletas roubadas e furtadas em Teresina. A maior parte destes ve\303\255culos \303\251 vendida para pessoas dos munic\303\255pios do interior atrav\303\251s de<br>documentos e notas falsas.</p><p>O delegado Francisco Costa, o Bareta, explica que alguns dos ve\303\255culos s\303\243o ainda usados para a pr\303\241tica de outros crimes, inclusive no interior do Estado. \"T\303\252m aumentado bastante as ocorr\303\252ncias em que bandidos usam motocicletas para cometer homic\303\255dios, latroc\303\255nios (roubo seguido de morte) e assaltos\", aponta.</p><p>O aumento desses casos em que bandidos usam motocicletas para a pr\303\241tica de delitos est\303\241 intimamente ligado a outro fator: \303\251 muito grande o n\303\272mero de motocicletas na capital e no interior, cuja frota cresceu consideravelmente nos \303\272ltimos anos, at\303\251 em fun\303\247\303\243o da facilidade para se adquirir esses ve\303\255culos.</p><p>Mas, segundo o delegado Bar\303\252ta, a pol\303\255cia tamb\303\251m est\303\241 intensificando a fiscaliza\303\247\303\243o e apreendendo os ve\303\255culos que s\303\243o produto de furto e roubo. \"Este ano mesmo j\303\241 apresentamos um planejamento t\303\241tico para a Secretaria de Seguran\303\247a para uma atua\303\247\303\243o mais integrada com os comandos de pol\303\255cia do interior do Piau\303\255\", acrescentou o delgado da Polinter.</p><p><br><strong>Cerca de 500 ve\303\255culos aguardam decis\303\243o da Justi\303\247a no p\303\241tio da Polinter</strong></p><p>Carros e motocicletas lotam o p\303\241tio da Polinter, delegacia especializada de repress\303\243o a Furtos e Roubos de Ve\303\255culos, em Teresina. S\303\243o aproximadamente 500 itens, ve\303\255culos e partes deles, como motores, carenagens, que foram apreendidos e recuperados. Boa parte dos ve\303\255culos aguarda decis\303\243o da Justi\303\247a para sa\303\255rem de l\303\241. S\303\243o aqueles em que os inqu\303\251ritos j\303\241<br>foram conclu\303\255dos e os respons\303\241veis n\303\243o aparecem. H\303\241 ainda casos em que a libera\303\247\303\243o depende da burocracia.</p><p>Atualmente, os mais velhos \"h\303\263spedes\" ocupam os p\303\241tios desde 2002. Segundo o delegado Francisco Costa, o Bareta, a maioria dos ve\303\255culos est\303\241 com chassi adulterado. \"Se o respons\303\241vel provar origem l\303\255cita pode retirar, caso contr\303\241rio n\303\243o \303\251<br>devolvido e depende de decis\303\243o da Justi\303\247a\", explica.</p><p>H\303\241 ainda casos em que o estado que o item est\303\241 n\303\243o compensa para o propriet\303\241rio a retirada. Algumas motos se encontram em situa\303\247\303\243o t\303\243o prec\303\241ria que n\303\243o compensa para o propriet\303\241rio retirar. Tamb\303\251m nesta situa\303\247\303\243o autom\303\263veis e motocicletas de<br>outros estados e de ocorr\303\252ncias em outros munic\303\255pios.</p><p>No local, n\303\243o existe uma estrutura adequada para o armazenamento de ve\303\255culos que ficam em meio ao mato, sob sol e chuva. No dep\303\263sito, os ve\303\255culos est\303\243o relacionados ainda \303\240s situa\303\247\303\265es que dificultam a localiza\303\247\303\243o do respons\303\241vel e com isso os<br>p\303\241tios v\303\243o enchendo. \"Quando os ve\303\255culos s\303\243o de ocorr\303\252ncias de outros estados, h\303\241 mais dificuldade de localizar o propriet\303\241rio. Mas temos feito um trabalho mais integrado com as pol\303\255cias de outros estados\", declara Bar\303\252ta.</p><p>De acordo com a Polinter, todos os ve\303\255culos e pe\303\247as que chegam ao local passam por uma vistoria antes de entrar no p\303\241tio. Depois, todas as informa\303\247\303\265es, como modelo, placa, chassi, n\303\272mero do boletim de ocorr\303\252ncia, do inqu\303\251rito, data de entrada,<br>s\303\243o inseridas em um arquivo.</p><p>Com essa organiza\303\247\303\243o, a delegacia mant\303\251m atualizados os dados sobre o que h\303\241 sob a sua responsabilidade. Quando o ve\303\255culo \303\251 retirado, \303\251 informado no sistema. \"S\303\263 sai daqui se estiver com o carimbo do cart\303\263rio central e ap\303\263s outra vistoria\", afirma Bar\303\252ta.</p><p><br><strong>Quem tem carro roubado pode pedir a restitui\303\247\303\243o do IPVA</strong></p><p><br>Voc\303\252 sabia que se o seu carro for roubado voc\303\252 tem direito \303\240 restitui\303\247\303\243o do Imposto sobre a Propriedade de Ve\303\255culos Automotores (IPVA)? O imposto a ser devolvido varia de acordo com o valor j\303\241 pago do IPVA e com o m\303\252s em que o carro foi roubado. A lei \303\251 nacional, ratificada pela Lei n\302\272 5.911/09, de autoria da ent\303\243o deputada estadual L\303\255lian Martins (PSB) e o prazo que o motorista tem para pedir a devolu\303\247\303\243o \303\251 o mesmo em todo o pa\303\255s.</p><p>A lei prev\303\252 a devolu\303\247\303\243o do dinheiro proporcional ao tempo em que o propriet\303\241rio ficou sem o ve\303\255culo, contando sempre a partir do m\303\252s seguinte ao crime. Por exemplo, quem quitou o IPVA e ficou sem o carro este m\303\252s, recebe a metade do dinheiro de volta em mar\303\247o. A v\303\255tima n\303\243o pode deixar de registrar o boletim de ocorr\303\252ncia para ter direito ao benef\303\255cio.</p><p>Al\303\251m do boletim, \303\251 preciso um registro de roubo no Departamento de Tr\303\242nsito e solicitar o benef\303\255cio junto \303\240 Secretaria da\302\240 Fazenda (Sefaz), em qualquer ag\303\252ncia de atendimento, protocolando os documentos no departamento financeiro.</p><p>De acordo com a Sefaz, caso o ve\303\255culo seja recuperado, o contribuinte ter\303\241 que recolher o imposto integral 30 dias ap\303\263s o registro, tendo como base o boletim de ocorr\303\252ncia. Vale lembrar que o contribuinte que estiver inadimplente com o IPVA de algum outro exerc\303\255cio ou qualquer outro tributo devido ao Estado n\303\243o poder\303\241 resgatar o valor enquanto houver a pend\303\252ncia.</p><p>O imposto dever\303\241 ser pago em prazo m\303\251dio de 60 dias. \"O contribuinte n\303\243o pode deixar de trazer todos os documentos<br>necess\303\241rios para dar entrada em seu processo, pois com a falta destes documentos a restitui\303\247\303\243o n\303\243o poder\303\241 ser realizada\",<br>completa a coordenadora de Impostos Diretos e Taxas, Maria das Gra\303\247as Lopes.</p><p>\302\240</p>"
      end

      it "should extract the news from the page" do
        url = 'http://portalodia.com/noticias/mundo/homem-chama-a-policia-porque-nao-quer-fazer-sexo-com-a-mulher-100984.html'
        @uri = URI.parse(url)
        response = Net::HTTP.get_response(@uri)
        @parsed_page = Readability::Document.new(Nokogiri::HTML(response.body), @uri.host, @uri.request_uri)
        @content = @parsed_page.content
        response = Net::HTTP.get_response(@uri)

        @content.should == "<p>A pol\303\255cia alem\303\243 informou nesta ter\303\247a-feira que recebeu um chamado no m\303\255nimo inusitado. Um homem da cidade de Waiblingen, distrito de Stuttgart, ligou para os policiais porque n\303\243o queria mais fazer sexo com sua mulher.</p><p>De acordo com ele, apesar de recusar seguidamente as ofertas, ela continua insistindo e n\303\243o o\302\240deixa dormir. O casal, que tem dois filhos, est\303\241 junto h\303\241 18 anos, mas j\303\241 n\303\243o dorme na mesma cama h\303\241 quatro.\302\240</p><p>Embora o caso seja curioso, n\303\243o \303\251 in\303\251dito no pa\303\255s europeu. Em 2006, a pol\303\255cia de Aachen, oeste da Alemanha, foi acionada por uma mulher que acusava o marido de n\303\243o cumprir suas obriga\303\247\303\265es conjugais.</p><p>Na ocasi\303\243o, ap\303\263s meses sem nenhum contato f\303\255sico, ela acordou no meio da madrugada e exigiu que o c\303\264njuge satisfizesse suas necessidades sexuais. Frustrada por ter seu pedido negado, ela acionou os agentes, que nada puderam fazer.</p><p>O porta voz da pol\303\255cia, Paul Kemen, explicou \303\240 \303\251poca que os policiais n\303\243o se sentiram capazes de resolver o caso. \"O que eles puderam fazer foi abrir uma ocorr\303\252ncia para o caso de uma poss\303\255vel interven\303\247\303\243o futura\", disse.\302\240</p>"
      end
    end

    describe "meio e mensagem" do
      it "should extract the news from the page" do
        url = 'http://www.mmonline.com.br/noticias!noticiasOpiniao.action?idArtigo=4184'
        @uri = URI.parse(url)
        response = Net::HTTP.get_response(@uri)
        @parsed_page = Readability::Document.new(Nokogiri::HTML(response.body),
        @uri.host, @uri.request_uri)
        @content = @parsed_page.content

        @content.should == "<div>\n<div> \n <p> \n \n 21/02/2011\n \n </p>\n \n Um novo jogo se desenha\n \n Edi\347\343o 1447 do Meio &amp; Mensagem\n \n <p></p>\n <p>A principal reportagem desta edi\347\343o traz um interessante panorama sobre a disputa pelos direitos de transmiss\343o do maior produto de m\355dia da televis\343o brasileira, em virtude da decis\343o do Clube dos 13 de promover um leil\343o para as emissoras de TV aberta interessadas em transmitir o Campeonato Brasileiro no tri\352nio 2012-14. Est\341 prevista para esta semana a publica\347\343o de um edital estabelecendo as regras dessa concorr\352ncia. O que est\341 sacramentado, at\351 por conta de uma decis\343o do Cade de outubro do ano passado, \351 a divis\343o desses direitos em cinco plataformas: TV aberta, TV por assinatura, pay-per-view, internet e telefonia m\363vel.H\341 uma apreens\343o geral do mercado publicit\341rio em torno da possibilidade da transmiss\343o do Brasileir\343o migrar da Globo, onde est\341 h\341 quase duas d\351cadas, para a Record, que, com muita compet\352ncia, alardeia pelos quatro cantos que tem caminh\365es de dinheiro para bancar o aumento da oferta inicial do Clube dos 13 &#8211; de R$ 250 milh\365es para R$ 500 milh\365es, s\363 para TV. Valor inicialmente recha\347ado pela Globo.O pacote de futebol da emissora l\355der \351 o mais valorizado do mercado e tem como ponto forte justamente a entrega de m\355dia que a rede possibilita aos seus cotistas. A migra\347\343o do futebol para a Record deixa s\351rias d\372vidas:1o) se o mercado ir\341 bancar os altos investimentos necess\341rios feitos pela emissora para transmitir o campeonato, e,2o) se a segunda televis\343o do Pa\355s tem uma grade de programa\347\343o atraente a ponto de sustentar um pacote t\343o rent\341vel como hoje \351 o do futebol da Globo.A despeito da polaridade entre Globo e Record pelos direitos de transmiss\343o da TV, esse leil\343o do Clube dos 13 pode mudar de uma forma ainda maior a configura\347\343o do jogo da m\355dia atual. Ao disponibilizar a divis\343o desses direitos em cinco modalidades, entre as quais internet e telefonia celular, abre-se uma grande oportunidade para as empresas de telecomunica\347\365es entrarem para valer nesse neg\363cio.Em um cen\341rio no qual os dispositivos m\363veis como os tablets crescem de forma exponencial no Brasil e no mundo &#8211; s\363 para se ter uma ideia, no Mobile World Congress, realizado semana passada em Barcelona, cerca de 50 fabricantes lan\347aram concorrentes do iPad &#8211;, e o governo tem como prioridade na \341rea de comunica\347\365es democratizar o acesso \340 banda larga, a mobilidade \351 um ponto important\355ssimo a ser levado em conta no cipoal de possibilidades que se desenha neste cen\341rio. Por raz\365es \363bvias, as empresas de telecomunica\347\365es podem se tornar ainda mais poderosas caso passem a abarcar em seus pacotes de oferta tamb\351m os jogos do Brasileir\343o. Terra/Telef\364nica e iG/Oi j\341 se sentaram com os caciques do Clube dos 13 para apresentarem suas propostas sobre o assunto.Nessas discuss\365es todas, parece que uma parte fundamental deste neg\363cio est\341 sendo deixada de lado: o torcedor. N\343o h\341 d\372vida de que o mundo digital e, em especial, as m\355dias sociais, deram muito mais poder aos torcedores, transformando a rela\347\343o antes linear entre f\343s, \355dolos, clubes e marcas. Experi\352ncias internacionais e algumas ainda incipientes por aqui demonstram que eles est\343o dispostos a pagar por algo que enxerguem como valor. Diante disso, saber a melhor forma de se relacionar com eles \351 mais do que estrat\351gico, \351 fundamental nesse novo jogo que se desenha.</p>\n <div>\n <p>Publicidade</p>\n <div>\n \n \n \n </div>\n </div>\n \n \n \n </div>\n<div>\n Editorial\n <p>\n Regina Augusto\n </p>\n \n \n \n \n </div>\n</div>"
      end
    end

    describe "slide share" do
      it 'should extract the slides' do
        url = "http://www.slideshare.net/plataformatec/classificao-de-textos-dev-in-sampa-28nov2009"
        @uri = URI.parse(url)
        response = Net::HTTP.get_response(@uri)
        @parsed_page = Readability::Document.new(Nokogiri::HTML(response.body), @uri.host, @uri.request_uri)
        @content = @parsed_page.content

        @content.should == " <div style=\"width:425px\" id=\"__ss_2606283\">\n <strong style=\"display:block;margin:12px 0 4px\">\n <a href=\"/plataformatec/classificao-de-textos-dev-in-sampa-28nov2009\" title=\"Classifica\303\247\303\243o de textos - Dev in Sampa - 28nov2009\">\n Classifica\303\247\303\243o de textos - Dev in Sampa - 28nov2009\n </a>\n </strong>\n <object id=\"__sse2606283\" width=\"425\" height=\"355\">\n <param name=\"movie\" value=\"http://static.slidesharecdn.com/swf/ssplayer2.swf?doc=devinsampa-2009mini-091129060000-phpapp01&amp;stripped_title=classificao-de-textos-dev-in-sampa-28nov2009\">\n<param name=\"allowFullScreen\" value=\"true\">\n<param name=\"allowScriptAccess\" value=\"always\">\n<embed name=\"__sse2606283\" src=\"http://static.slidesharecdn.com/swf/ssplayer2.swf?doc=devinsampa-2009mini-091129060000-phpapp01&amp;stripped_title=classificao-de-textos-dev-in-sampa-28nov2009\" type=\"application/x-shockwave-flash\" allowscriptaccess=\"always\" allowfullscreen=\"true\" width=\"425\" height=\"355\"></embed></object>\n </div>"
      end
    end

    describe "Google Videos" do
      it 'should extract the videos from the anchor parameter' do
        url = "http://video.google.com/videoplay?docid=-4176721009838609904&hl=en#docid=-3818636184384512295"
        uri = URI.parse(url)
        response = Net::HTTP.get_response(uri)
        @parsed_page = Readability::Document.new(Nokogiri::HTML(response.body), uri.host, uri.request_uri + "#" + uri.fragment)
        @content = @parsed_page.content

        @content.should == " <div>\n <embed id=\"VideoPlayback\" src=\"http://video.google.com/googleplayer.swf?docid=-3818636184384512295&amp;hl=en&amp;fs=true\" style=\"width:400px;height:326px\" allowfullscreen=\"true\" allowscriptaccess=\"always\" type=\"application/x-shockwave-flash\"></embed>\n</div>"
      end

      it 'should extract the videos from the anchor parameter' do
        url = "http://video.google.com/videoplay?docid=-4176721009838609904&hl=en"
        uri = URI.parse(url)
        response = Net::HTTP.get_response(uri)
        @parsed_page = Readability::Document.new(Nokogiri::HTML(response.body), uri.host, uri.request_uri)
        @content = @parsed_page.content

        @content.should == " <div>\n <embed id=\"VideoPlayback\" src=\"http://video.google.com/googleplayer.swf?docid=-4176721009838609904&amp;hl=en&amp;fs=true\" style=\"width:400px;height:326px\" allowfullscreen=\"true\" allowscriptaccess=\"always\" type=\"application/x-shockwave-flash\"></embed>\n</div>"
      end

    end


  end



  describe "#has_special_rule?" do
    use_vcr_cassette 'pages', :record => :new_episodes

    it "should return true when I have a special rule" do
      url = "http://portalodia.com/noticias/piaui/mais-de-um-veiculo-e-roubado-por-dia-na-capital-102189.html"
      @uri = URI.parse(url)
      response = Net::HTTP.get_response(@uri)

      @parsed_page = Readability::Document.new(Nokogiri::HTML(response.body), @uri.host, @uri.request_uri)
      @parsed_page.has_special_rule?.should be_true
    end

    it "should return false when I don't have a special rule" do
      url = "http://globoesporte.globo.com/futebol/times/internacional/noticia/2011/02/inter-ainda-aguarda-sinal-verde-da-fifa-para-cavenaghi-ser-relacionado.html"
      @uri = URI.parse(url)
      response = Net::HTTP.get_response(@uri)
      @parsed_page = Readability::Document.new(Nokogiri::HTML(response.body), @uri.host, @uri.request_uri)
      @parsed_page.has_special_rule?.should be_false
    end
  end
end