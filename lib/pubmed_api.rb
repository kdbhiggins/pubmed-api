require "pubmed_api/version"
require 'open-uri'
require 'nokogiri'

module PubmedApi

  class Interface
    
    WAIT_TIME = 0.5 # seconds
    
    DEFAULT_OPTIONS = {:retmax => 100000,
                       :retstart => 0,
                       :tool => 'ruby-pubmed_search',
                       :database => 'pubmed', #which database eq pubmed/nlmcatalog
                       :verb => 'search', #which API verb to use e.g. search/fetch
                       :email => '',
                       :reldate => 90, #How far back shall we go in days 
                       :load_all_pmids => false }
                       

    URI_TEMPLATE = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/e{verb}.fcgi?db={database}&tool={tool}&email={email}'+
                     '&reldate={reldate}&retmax={retmax}&retstart={retstart}&{query}&rettype=fasta&retmode=xml'
    
    SearchResult = Struct.new(:count, :pmids, :mesh_terms, :phrases_not_found)


    class << self
      # Performs a search to PubMed via eUtils with the given term +String+, and returns a +PubmedSearch+ object modeling the response.
      #
      # Accepts a +Hash+ of options. Valid options are 
      # * :retmax - Defaults to 100,000 which is the largest retmax that PubMed will honor.
      # * :retstart - Defaults to 0. Set higher if you need to page through results. You shouldn't need to do that manually, because of the +load_all_pmids+ option
      # * :tool - Defaults to 'ruby-pubmed_search', set to the name of your tool per EUtils parameters specs
      # * :email - Defaults to '', set to your email address per EUtils parameters specs
      # * :load_all_pmids - Defaults to +false+. If this is set +true+, then search will continue sending eSearches with an increasing retstart until the list of pmids == count. For instance, an eSearch for "Mus musculus" will return ~951134 results, but the highest retmax allowable is 100000. With +load_all_pmids+ set +true+, search will automatically perform 10 eSearches and return the entire list of pmids in one go.
      def search(term, options={})
        
        options = DEFAULT_OPTIONS.merge(options)
      
        results = do_search(term, options)
      
        if options[:load_all_pmids]
          # Send off subsequent requests to load all the PMIDs, add them to the results
          (options[:retmax]..results.count).step(options[:retmax]) do |step|
            results.pmids << do_search(term, options.merge({:retstart => step})).pmids
          end 
        end
      
        results
      end

      # Performs a search and parses the response
      def do_search(search_term, options)
        wait
        doc = make_api_request(options.merge({:query => 'term='+search_term}))
        parse_search(doc)
      end

      def fetch_papers(ids)
        xml = fetch_records(ids, 'pubmed')
        parse_papers(xml)
      end

      def fetch_journals(nlmids)
        #Change the ids of those wierd journals 
        nlmids = nlmids.map { |e|  ((e.include? 'R') ? convert_odd_journal_ids(e) : e ) }
        xml = fetch_records(nlmids, 'nlmcatalog')
        parse_journals(xml)       
      end

      def fetch_records(ids, database)

        xml_records = []
        
        options = DEFAULT_OPTIONS

        #dice array into reasonable length chunks for download
        n_length = 500
        # TODO paralellise? 
        ids.each_slice(n_length) do |slice|
      
          #Turn string to something html friendly 
          id_string = slice.join(",")
          doc = make_api_request(options.merge({:verb => 'fetch',:database => database, :query => 'id='+id_string}))
          records = doc.xpath('./*/*')
          xml_records << records

        end
        xml_records.flatten
      end

      #Maked the HTTP request and return the responce
      #TODO handle failures
      #Log API calls?
      def make_api_request(options)
          url = expand_uri(@uri_template, options)
          Nokogiri::XML( open url )
      end

    

      #Some journals have odd NLMIDs that need to be searched for rarther than accessed directly. 
      def convert_odd_journal_ids(id)
        
        new_id = nil
        results = search(id, {:database => 'nlmcatalog', :reldate => '100000'})
        if results.pmids.length ==1
          new_id = results.pmids[0]
        else
          puts "failed to convert " + id.to_s
        end
        new_id.to_s
      end

      # 300ms minimum wait.
      def wait
        sleep WAIT_TIME 
      end
      
      
      private
      
      
      # This is a semi-hack to do URI templating. It used to be its own gem, but shit happened.
      def expand_uri(uri, options)
        uri.gsub(/\{(.*?)\}/) { URI.encode( (options[$1] || options[$1.to_sym] || '').to_s ) rescue '' }
      end


      def parse_search(doc)

        results = SearchResult.new
        results.pmids = []
        results.mesh_terms = []

        results.count = doc.xpath('/eSearchResult/Count').first.content.to_i
        
        doc.xpath('/eSearchResult/IdList/Id').each {|n| results.pmids << n.content.to_i}
              
        doc.xpath('/eSearchResult/TranslationStack/TermSet/Term').each do |n|
          if n.content =~ /"(.*)"\[MeSH Terms\]/
            results.mesh_terms << $1
          end
        end
        
        doc.xpath('/eSearchResult/ErrorList/PhraseNotFound').each {|n| results.phrases_not_found << n.content }
        results
      end

      PaperStruct = Struct.new( :title, :abstract, :article_date, :pubmed_date, :date_appeared,
                                :doi, :authors, :uid, :nlmid, :journal, :complete, :url, :pdf_url)

      def parse_papers(papers_xml)

        results = []

        papers_xml.each do |paper|
          
          #check it's actually a paper
          if paper.xpath('/*/*').first.name().eql?('PubmedArticle')

            
            paper_output = PaperStruct.new
     
            paper_output.title = paper.at('ArticleTitle').text

            begin
              paper_output.abstract = paper.at('Abstract').text
            rescue NoMethodError
            
            end
            
            begin
              #Date in Y/M/D format
              article_date =  Date.new( paper.at('ArticleDate/Year').text.to_i,  paper.at('ArticleDate/Month').text.to_i, paper.at('ArticleDate/Day').text.to_i)
              paper_output.article_date = article_date 
            rescue NoMethodError
               #puts "no date " +  " " + paper.css('PMID').text + " " + paper.css('ArticleTitle').text
               paper_output.article_date =  Date.new()
            end

            #Parse mutlitple PubMedPubDate dates  
            dates = paper.css('PubMedPubDate')

            paper_output.uid =  parse_pmid(paper.css('PMID').text)

            pub_date = [0,0,0]

            dates.each do |node|
              if node.attributes["PubStatus"].to_s == "entrez"
                pub_date = Date.new( node.at('Year').text.to_i,  node.at('Month').text.to_i, node.at('Day').text.to_i)
                paper_output.pubmed_date = pub_date
                paper_output.date_appeared = pub_date
              end
            end

            ids = paper.css('ArticleId')
          
            ids.each do |node|
              v = node.attributes["IdType"].to_s
              if v == 'doi'
                paper_output.doi = node.text
              end
            end


            #Extract the authors as friendly string for now...
            #TODO handle authors properly 
            authors = paper.css('Author')
            auth_arr = parse_authors(authors)
            
            author_string = ''

            auth_arr.each do |a|
              author_string += a[1] + ' ' + a[2] +', '
            end
            
            #cut additional ', ' off end 
            author_string = author_string[0..-3]
            paper_output.authors = author_string
            paper_output.nlmid = paper.css('NlmUniqueID').text
            
            
            results << paper_output
          end
        end
        
        return results
      end

      JournalStruct = Struct.new( :issn, :nlmid, :title_long, :title_short, :started,:frequency)

      def parse_journals(journals_xml)

        j_struc_arr = []
        
        journals_xml.each do |j|
          j_struc = JournalStruct.new(j.css('ISSN').text, j.css('NlmUniqueID').text, j.xpath('./TitleMain/Title').text,
                                      j.css('MedlineTA').text, j.css('PublicationFirstYear').text, j.css('Frequency').text)
          j_struc_arr << j_struc
        end

        j_struc_arr
      end

      def parse_pmid(pmid)
        pmid = pmid.gsub('.', '')

        if pmid.length > 8
          pmid = pmid[0,8]
        end
        pmid
      end

      def parse_authors(authors)

        authors_output  =[]

        authors.each do |node|
          author_arr =  Array.new(3,"")

          if v = node.at_css('ForeName')
            author_arr[0] = v.text
          end 

          if v = node.at_css('Initials')
            author_arr[1] = v.text
          end 

          if v = node.at_css('LastName')
            author_arr[2] = v.text
          end

          authors_output << author_arr
        end
      
        return authors_output
      end
    end
  end
  
end
