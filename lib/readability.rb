require 'rubygems'
require 'nokogiri'
require 'cgi'

# so to run with non-Rails projects
class Object
  def try(method, *arguments)
    send(method, *arguments) if respond_to? method
  end
end

module Readability
  class Document
    TEXT_LENGTH_THRESHOLD = 25
    RETRY_LENGTH = 250

    attr_accessor :document, :base_uri, :request, :options, :best_candidate

    def initialize(document, base_uri, request, options = {})
      @document = document
      @base_uri = base_uri
      @request = request
      @options = options
    end

    REGEXES = {
        :unlikelyCandidatesRe => /combx|comment|disqus|foot|header|menu|meta|nav|rss|shoutbox|sidebar|sponsor/i,
        :okMaybeItsACandidateRe => /and|article|body|column|main/i,
        :positiveRe => /article|body|content|entry|hentry|page|pagination|post|text/i,
        :negativeRe => /combx|comment|contact|foot|footer|footnote|link|media|meta|promo|related|scroll|shoutbox|sponsor|tags|widget/i,
        :divToPElementsRe => /<(a|blockquote|dl|div|img|ol|p|pre|table|ul)/i,
        :replaceBrsRe => /(<br[^>]*>[ \n\r\t]*){2,}/i,
        :replaceFontsRe => /<(\/?)font[^>]*>/i,
        :trimRe => /^\s+|\s+$/,
        :normalizeRe => /\s{2,}/,
        :killBreaksRe => /(<br\s*\/?>(\s|&nbsp;?)*){1,}/,
        :videoRe => /(www\.)?(youtube|vimeo|ted|player\.vimeo)\.com/i
    }

    # should we get rid of this?
    def make_html
      @document.encoding = 'UTF-8'
      @best_candidate = nil
    end

    def has_special_rule?
      !!rules[@base_uri]
    end


    def content(remove_unlikely_candidates = true)
      debug "Starting the content heuristic"
      @document.css("script, style").each {|el| el.remove }
      @document.search('//comment()').each {|el| el.remove }

      article = youtube if is_youtube? && remove_unlikely_candidates
      article = vimeo if is_vimeo? && remove_unlikely_candidates
      article = ted if is_ted? && remove_unlikely_candidates
      article = slideshare if is_slideshare? && remove_unlikely_candidates
      article = google_videos if is_google_videos? && remove_unlikely_candidates
      article = apply_custom_rule if has_special_rule?

      if article && remove_unlikely_candidates
        content = article.to_html.gsub(/[\r\n\f]+/, "\n" ).gsub(/[\t ]+/, " ").gsub(/&nbsp;/, " ")
        if rules[@base_uri].try(:encoding) && rules[@base_uri].encoding == 'ISO-8859-1'
          return convert_to_utf8(content)
        end
        return content
      else
        remove_unlikely_candidates! if remove_unlikely_candidates
        transform_misused_divs_into_paragraphs!
        candidates = score_paragraphs(options[:min_text_length] || TEXT_LENGTH_THRESHOLD)
        best_candidate = select_best_candidate(candidates)
        article = get_article(candidates, best_candidate)

        cleaned_article = sanitize(article, candidates, options)

        if remove_unlikely_candidates && article.text.strip.length < (options[:retry_length] || RETRY_LENGTH)
          make_html
          content(false)
        else
          cleaned_article
        end
      end
    end

    def is_youtube?
      (@base_uri.to_s =~ /(www\.)?youtube.com/)
    end

    def is_vimeo?
      (@base_uri.to_s =~ /(www.)?vimeo.com/)
    end

    def is_ted?
      (@base_uri.to_s =~ /(www.)?ted.com\/talks/)
    end

    def is_slideshare?
      (@base_uri.to_s =~ /(www.)?slideshare.net/)
    end

    def is_special_case?
      (@base_uri.to_s =~ REGEXES[:videoRe])
    end

    def is_google_videos?
      (@base_uri.to_s =~ /video.google.com/)
    end

    def google_videos
      uri = URI.parse(@base_uri + @request)

      if uri.fragment && uri.fragment != ""
        video_id = CGI::parse(uri.fragment)['docid'].first
      else
        video_id = CGI::parse(uri.query)['docid'].first
      end
      Nokogiri::HTML.fragment <<-HTML
        <div>
          <embed id=VideoPlayback src=http://video.google.com/googleplayer.swf?docid=#{video_id}&hl=en&fs=true style=width:280px; allowFullScreen=true allowScriptAccess=always type=application/x-shockwave-flash>
          </embed>
        </div>
      HTML

    end

    def slideshare
      title = @document.css("h1.h-slideshow-title").inner_html
      movie_value = @document.css("link[name='media_presentation']").first.attributes["href"].value
      Nokogiri::HTML.fragment <<-HTML
        <div style=\"width:280px\" id=\"__ss_2606283\">
          <strong style=\"display:block;margin:12px 0 4px\">
            <a href=\"#{@request}\" title=\"#{title}\">
              #{title}
            </a>
          </strong>
          <object id=\"__sse2606283\" width=\"280\">
            <param name=\"movie\" value=\"#{movie_value}\" />
            <param name=\"allowFullScreen\" value=\"true\"/>
            <param name=\"allowScriptAccess\" value=\"always\"/>
            <embed name=\"__sse2606283\" src=\"#{movie_value}\" type=\"application/x-shockwave-flash\" allowscriptaccess=\"always\" allowfullscreen=\"true\" width=\"280\"></embed>
          </object>
        </div>
      HTML
    end

    def youtube
      debug("I have a Youtube video page")
      if @request =~ /\?v=([_\-a-z0-9]+)&?/i
        Nokogiri::HTML.fragment <<-HTML
          <object width="280" height="172"><param name="movie" value="http://www.youtube.com/v/{$1}?version=3&amp;hl=en_US&amp;rel=0"></param><param name="allowFullScreen" value="true"></param><param name="allowscriptaccess" value="always"></param><embed src="http://www.youtube.com/v/{$1}?version=3&amp;hl=en_US&amp;rel=0" type="application/x-shockwave-flash" width="280" height="172" allowscriptaccess="always" allowfullscreen="true"></embed></object>
        HTML
      else
        nil
      end
    end

    def vimeo
      debug("I have a Vimeo video page")
      # matches non-channel or pages that used swfobject to print player
      if @document.css("#clip_id")
        Nokogiri::HTML.fragment("<iframe src=\"http://player.vimeo.com/video/#{@document.css("#clip_id").attr('value')}\" width=\"280\" frameborder=\"0\"></iframe>")
      # matches channel pages
      elsif player = @document.css(".player")
        html = ""
        player.each do |video|
          if video.to_html =~ /clip_id=([0-9]+)/
            html << "<iframe src=\"http://player.vimeo.com/video/#{$1}\" width=\"280\" frameborder=\"0\"></iframe>"
          end
        end
        Nokogiri::HTML.fragment(html)
      else
        nil
      end
    end

    def ted
      debug("I have a TED video page")
      if (player = @document.css(".copy_paste")).present?
        unless player.first.attr("value").blank?
          Nokogiri::HTML.fragment(player.first.attr("value").to_s)
        else
          nil
        end
      else
        nil
      end
    end

    def get_article(candidates, best_candidate)
      # Now that we have the top candidate, look through its siblings for content that might also be related.
      # Things like preambles, content split by ads that we removed, etc.

      sibling_score_threshold = [10, best_candidate[:content_score] * 0.2].max
      output = Nokogiri::XML::Node.new('div', @document)
      begin
        if best_candidate[:elem].try(:parent)
          best_candidate[:elem].parent.try(:children).each do |sibling|
            append = false
            append = true if sibling == best_candidate[:elem]
            append = true if candidates[sibling] && candidates[sibling][:content_score] >= sibling_score_threshold

            if sibling.name.downcase == "p"
              link_density = get_link_density(sibling)
              node_content = sibling.text
              node_length = node_content.length

              if node_length > 80 && link_density < 0.25
                append = true
              elsif node_length < 80 && link_density == 0 && node_content =~ /\.( |$)/
                append = true
              end
            end

            if append
              sibling.name = "div" unless %w[div p].include?(sibling.name.downcase)
              output << sibling
            end
          end
        end
      end

      output
    end

    def select_best_candidate(candidates)
      @best_candidate ||= begin
        sorted_candidates = candidates.values.sort { |a, b| b[:content_score] <=> a[:content_score] }

        debug("Top 5 candidates:")
        sorted_candidates[0...5].each do |candidate|
          debug("Candidate #{candidate[:elem].try(:name)}##{candidate[:elem][:id]}.#{candidate[:elem][:class]} with score #{candidate[:content_score]}")
        end

        best_candidate = sorted_candidates.first || { :elem => @document.css("body").first, :content_score => 0 }
        #debug("Best candidate #{best_candidate[:elem].andand.name} with score #{best_candidate[:content_score]}")
        best_candidate
      end
    end

    def get_link_density(elem)
      link_length = elem.css("a").map {|i| i.text}.join("").length
      text_length = elem.text.length
      link_length / text_length.to_f
    end

    def score_paragraphs(min_text_length)
      candidates = {}
      @document.css("p,td").each do |elem|
        parent_node = elem.parent
        grand_parent_node = parent_node.respond_to?(:parent) ? parent_node.parent : nil
        inner_text = elem.text

        # If this paragraph is less than 25 characters, don't even count it.
        next if inner_text.length < min_text_length

        candidates[parent_node] ||= score_node(parent_node)
        candidates[grand_parent_node] ||= score_node(grand_parent_node) if grand_parent_node

        content_score = 1
        content_score += inner_text.split(',').length
        content_score += [(inner_text.length / 100).to_i, 3].min

        candidates[parent_node][:content_score] += content_score
        candidates[grand_parent_node][:content_score] += content_score / 2.0 if grand_parent_node
      end

      # Scale the final candidates score based on link density. Good content should have a
      # relatively small link density (5% or less) and be mostly unaffected by this operation.
      candidates.each do |elem, candidate|
        candidate[:content_score] = candidate[:content_score] * (1 - get_link_density(elem))
      end

      candidates
    end

    def class_weight(e)
      weight = 0
      if e[:class] && e[:class] != ""
        if e[:class] =~ REGEXES[:negativeRe]
          weight -= 25
        end

        if e[:class] =~ REGEXES[:positiveRe]
          weight += 25
        end
      end

      if e[:id] && e[:id] != ""
        if e[:id] =~ REGEXES[:negativeRe]
          weight -= 25
        end

        if e[:id] =~ REGEXES[:positiveRe]
          weight += 25
        end
      end

      weight
    end

    def convert_to_utf8(string)
      string.unpack("C*").pack("U*")
    end

    def score_node(elem)
      content_score = class_weight(elem)
      case elem.name.downcase
        when "div"
          content_score += 5
        when "blockquote"
          content_score += 3
        when "form"
          content_score -= 3
        when "th"
          content_score -= 5
      end
      { :content_score => content_score, :elem => elem }
    end

    def debug(str)
      puts "READABILITY : "+ str if options[:debug]
    end

    def remove_unlikely_candidates!
      @document.css("*").each do |elem|
        str = "#{elem[:class]}#{elem[:id]}"
        if str =~ REGEXES[:unlikelyCandidatesRe] && str !~ REGEXES[:okMaybeItsACandidateRe] && elem.name.downcase != 'body'
          debug("Removing unlikely candidate - #{str}")
          elem.remove
        end
      end
    end

    def transform_misused_divs_into_paragraphs!
      @document.css("*").each do |elem|
        if elem.name.downcase == "div"
          # transform <div>s that do not contain other block elements into <p>s
          if elem.inner_html !~ REGEXES[:divToPElementsRe]
            debug("Altering div(##{elem[:id]}.#{elem[:class]}) to p");
            elem.name = "p"
          end

        end
      end
    end

    def sanitize(node, candidates, options = {})
      node.css("h1, h2, h3, h4, h5, h6").each do |header|
        header.remove if class_weight(header) < 0 || get_link_density(header) > 0.33
      end

      node.css("form").each do |elem|
        elem.remove
      end

      node.css("iframe").each do |iframe|
        unless iframe.attr("src").to_s =~ REGEXES[:videoRe]
          iframe.remove
        end
      end

      # remove empty <p> tags
      node.css("p").each do |elem|
         elem.remove if elem.content.strip.empty?
      end

      # Conditionally clean <table>s, <ul>s, and <div>s
      node.css("table, ul, div").each do |el|
        weight = class_weight(el)
        content_score = candidates[el] ? candidates[el][:content_score] : 0
        name = el.name.downcase

        if weight + content_score < 0
          el.remove
          debug("Conditionally cleaned #{name}##{el[:id]}.#{el[:class]} with weight #{weight} and content score #{content_score} because score + content score was less than zero.")
        elsif el.text.count(",") < 10
          counts = %w[p img li a embed input].inject({}) { |m, kind| m[kind] = el.css(kind).length; m }
          counts["li"] -= 100

          content_length = el.text.strip.length  # Count the text length excluding any surrounding whitespace
          link_density = get_link_density(el)
          to_remove = false
          reason = ""

          if (counts["img"] > counts["p"]) && (counts["p"] > 0)
            reason = "too many images #{counts['p']}"
            to_remove = true
          elsif counts["li"] > counts["p"] && name != "ul" && name != "ol"
            reason = "more <li>s than <p>s"
            to_remove = true
          elsif counts["input"] > (counts["p"] / 3).to_i
            reason = "less than 3x <p>s than <input>s"
            to_remove = true
          elsif content_length < (options[:min_text_length] || TEXT_LENGTH_THRESHOLD) && (counts["img"] == 0 || counts["img"] > 2)
            reason = "too short a content length without a single image"
            to_remove = true
          elsif weight < 25 && link_density > 0.2
            reason = "too many links for its weight (#{weight})"
            to_remove = true
          elsif weight >= 25 && link_density > 0.5
            reason = "too many links for its weight (#{weight})"
            to_remove = true
          elsif (counts["embed"] == 1 && content_length < 75) || counts["embed"] > 1
            reason = "<embed>s with too short a content length, or too many <embed>s"
            to_remove = true
          end

          if to_remove
            debug("Conditionally cleaned #{name}##{el[:id]}.#{el[:class]} with weight #{weight} and content score #{content_score} because it has #{reason}.")
            el.remove
          end
        end
      end

      # We'll sanitize all elements using a whitelist
      base_whitelist = @options[:tags] || %w[div p]

      # Use a hash for speed (don't want to make a million calls to include?)
      whitelist = Hash.new
      base_whitelist.each {|tag| whitelist[tag] = true }
      ([node] + node.css("*")).each do |el|

        # If element is in whitelist, delete all its attributes
        if whitelist[el.node_name]
          el.attributes.each { |a, x| el.delete(a) unless @options[:attributes] && @options[:attributes].include?(a.to_s) }
          # Otherwise, replace the element with its contents
        else
          # keep getting whiny nils with nokogiri
          el.swap(el.text) rescue nil
        end

      end

      # Get rid of duplicate whitespace
      node.to_html.gsub(/[\r\n\f]+/, "\n" ).gsub(/[\t ]+/, " ").gsub(/&nbsp;/, " ")
    end

    private

    def rules
      if @base_uri =~ /^www\.(.*)$/
        @base_uri = $1
      end
      @rules ||= YAML.load_file(options[:exceptions_file] || File.dirname(__FILE__) + "/../special_rules.yml")["sites"]
    end

    def apply_custom_rule
      debug "Applying custom selector for : " + rules[@base_uri]['name']
      extracted = @document.css(rules[@base_uri]["css"])
      extracted.each do |elem|
        if (elem.try(:inner_html) =~ /^\W*$/)
          extracted.delete elem
        end
      end
      extracted
    end

  end


  private

  def remove_empty_tags(chunk)
    chunk.css("p").each do |elem|
      elem.remove if elem.content.strip.empty?
    end
  end
end