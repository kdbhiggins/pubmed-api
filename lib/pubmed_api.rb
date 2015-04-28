require 'pubmed_api/version'
require 'pubmed_api/parsers'
require 'open-uri'
require 'nokogiri'

module PubmedAPI

  class Interface

    WAIT_TIME = 0.5 # seconds
 

    DEFAULT_OPTIONS = {:tool => 'ruby-pubmed-api',
                       :database => 'pubmed', #which database eq pubmed/nlmcatalog
                       :verb => 'search', #which API verb to use e.g. search/fetch
                       :email => '',
                       :reldate => 90, #How far back shall we go in days 
                       :retmax => 100000,
                       :retstart => 0,
                       :load_all_pmids => false }
                     

    URI_TEMPLATE = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/e{verb}.fcgi?db={database}&tool={tool}&email={email}'+
                   '&reldate={reldate}&retmax={retmax}&retstart={retstart}&{query}&rettype=fasta&retmode=xml'

    class << self

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
        parser = XMLParser.new
        parser.parse_search(doc)
      end

      def fetch_papers(ids)
        xml = fetch_records(ids, 'pubmed')
        parser = XMLParser.new
        parser.parse_papers(xml)
      end

      def fetch_journals(nlmids)
        #Change the ids of those wierd journals 
        nlmids = nlmids.map { |e|  ((e.include? 'R') ? convert_odd_journal_ids(e) : e ) }
        xml = fetch_records(nlmids, 'nlmcatalog')
        parser = XMLParser.new
        parser.parse_journals(xml)       
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
          url = expand_uri(URI_TEMPLATE, options)
          Nokogiri::XML( open url )
      end

    
      #Some journals have odd NLMIDs that need to be searched for rarther than accessed directly.
      #TODO combine into single API request 
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
            
      def expand_uri(uri, options)
        uri.gsub(/\{(.*?)\}/) { URI.encode( (options[$1] || options[$1.to_sym] || '').to_s ) rescue '' }
      end

    end
  end
  
end
