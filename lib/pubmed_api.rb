require 'pubmed_api/version'
require 'pubmed_api/parsers'
require 'open-uri'
require 'nokogiri'

module PubmedAPI

  class Interface

    WAIT_TIME = 0.5 # seconds
 

    DEFAULT_OPTIONS = {:tool => 'ruby-pubmed-api',
                       :database => 'db=pubmed', #which database eq pubmed/nlmcatalog
                       :verb => 'search', #which API verb to use e.g. search/fetch
                       :email => '',
                       #:reldate => 90, #How far back shall we go in days
                       :add =>'', 
                       :retmax => 100000,
                       :retstart => 0,
                       :load_all_pmids => true }
                     

    URI_TEMPLATE = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/e{verb}.fcgi?{database}&tool={tool}&email={email}'+
                   '&reldate={reldate}&retmax={retmax}&retstart={retstart}&{query}&retmode=xml&{add}'

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
        xml = fetch_records(ids, {:verb => 'fetch',:database => 'db=pubmed'})
        parser = XMLParser.new
        papers = parser.parse_papers(xml)
        lookup_hash = get_fulltext_links(ids)
        
        papers.each do |p|
          if p.nil? or lookup_hash[p.pmid].nil?
             next
          else
            p.url =  lookup_hash[p.pmid].first.url 
          end
        end
      end

      def fetch_journals(nlmids)
        #Change the ids of those wierd journals 
        nlmids = nlmids.map { |e|  ((e.include? 'R') ? convert_odd_journal_ids(e) : e ) }
        xml = fetch_records(nlmids, {:verb => 'fetch',:database => 'db=nlmcatalog'})
        parser = XMLParser.new
        parser.parse_journals(xml)       
      end

     def get_fulltext_links(ids)
       opts = {:verb => 'link',  :add => 'cmd=llinks', :database => 'dbfrom=pubmed'}
       xml = fetch_records(ids, opts)

       parser = XMLParser.new
       lookup_hash = parser.parse_links(xml)
       missing = (ids - lookup_hash.keys)
       lookup_hash
     end


      def fetch_records(ids, opts={})

        xml_records = []
        
        options = DEFAULT_OPTIONS.merge(opts)

        #dice array into reasonable length chunks for download
        n_length = 500
        # TODO paralellise? 
        ids.each_slice(n_length) do |slice|
      
          #Turn string to something html friendly 
          id_string = slice.join(",")
          doc = make_api_request(options.merge({ :query => 'id='+id_string}))
          records = doc.xpath('./*/*')
          xml_records += records

        end

        xml_records
      end

      


      #Maked the HTTP request and return the responce
      #TODO handle failures
      def make_api_request(options)
          url = expand_uri(URI_TEMPLATE, options)
          Nokogiri::XML( open url )
      end

    
      #Some journals have odd NLMIDs that need to be searched for rarther than accessed directly.
      def convert_odd_journal_ids(id)
        
        new_id = nil
        results = search(id, {:database => 'db=nlmcatalog'})
        if results.pmids.length ==1
          new_id = results.pmids[0]
        else
          puts "failed to convert " + id.to_s
        end
        new_id.to_s
      end

      
      def get_journal_id_from_issn(issn)
        
        id = nil
        term = issn + "[ISSN]+AND+ncbijournals[filter]"

        results = search(term, {:database => 'db=nlmcatalog'})
        if results.pmids.length ==1
          id = results.pmids[0]
        else
          puts "failed to find " + issn.to_s
        end
        
        id.to_s
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
