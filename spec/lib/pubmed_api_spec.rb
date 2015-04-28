require 'spec_helper'

describe PubmedAPI do


  it "should perform a search" do
    strucs = PubmedAPI::Interface.search("quantum physics", {:load_all_pmids => true, :reldate => 90})    
    expect(strucs.length > 10)
  end

  it "should make an API call" do
  	options = PubmedAPI::Interface::DEFAULT_OPTIONS
  	options.merge({:query => 'term=scrotum'})
  	
  	doc = PubmedAPI::Interface.make_api_request(options)
    records = doc.xpath('./*/*')
    count = doc.xpath('/eSearchResult/Count').first.content.to_i
    expect(count > 0 )
    expect(records.length == count)
  end 
  

  it "should fetch a paper" do
    id = '25554862'
    title = "Completing the picture for the smallest eigenvalue of real Wishart matrices."
    strucs = PubmedAPI::Interface.fetch_papers([id])
    paper = strucs[0]
    expect(paper.title.eql?(title))
    expect(paper.pmid.eql?(id))
  end 

  it "should fetch a journal" do
    id = '0401141'
    title = 'Physical review letters.'
    strucs = PubmedAPI::Interface.fetch_journals([id])
    j = strucs[0]
    expect(j.title_long.eql?(title))
    expect(j.nlmid.eql?(id))
  end 
 
  it "it should fix strange journal ids" do
     fixed = PubmedAPI::Interface.convert_odd_journal_ids('16930290R')
     expect( fixed.eql?('100381'))
  end

end