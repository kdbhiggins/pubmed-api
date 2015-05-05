module PubmedAPI

  class XMLParser

  	SearchResult = Struct.new(:count, :pmids, :mesh_terms, :phrases_not_found)

  	def parse_search(doc)

  	  results = SearchResult.new
  	  results.pmids = []
  	  results.mesh_terms = []
      results.phrases_not_found = []

  	  results.count = doc.xpath('/eSearchResult/Count').first.content.to_i

  	  doc.xpath('/eSearchResult/IdList/Id').each {|n| results.pmids << n.content.to_s}
  	      
  	  doc.xpath('/eSearchResult/TranslationStack/TermSet/Term').each do |n|
  	    if n.content =~ /"(.*)"\[MeSH Terms\]/
  	      results.mesh_terms << $1
  	    end
  	  end

  	  doc.xpath('/eSearchResult/ErrorList/PhraseNotFound').each {|n| results.phrases_not_found << n.content }
  	  

      results
  	
    end


    PaperStruct = Struct.new( :title, :abstract, :article_date, :pubmed_date, :date_appeared,
                              :doi, :authors, :pmid, :nlmid, :journal, :complete, :url, :pdf_url)

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

          paper_output.pmid =  parse_pmid(paper.css('PMID').text)

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

    
    LinkStruct = Struct.new( :url, :pub_id, :pub_name, :cat)

    def parse_links(links_xml)
      
      l_struc_arr = []
      link_arr = []
      lookup_hash = Hash.new{ |a,b| a[b] = Array.new }
      
      links_xml.each do |node|
        
        node.css('IdUrlList/IdUrlSet').each do |links|
          id = links.xpath('Id').text

          links.css('ObjUrl').each do |l|
            l_struc = LinkStruct.new(l.xpath('Url').text, l.xpath('Provider/Id').text, l.xpath('Name').text,
                                        l.xpath('Category').text)
 
            lookup_hash[id] << l_struc
          end
        end
      end      
      
      lookup_hash
    end



    AuthorStruct = Struct.new( :fore_name, :initials, :last_name)
    
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