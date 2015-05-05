require 'spec_helper'

describe PubmedAPI do

  before(:all)  do 
    @q_results = PubmedAPI::Interface.search("quantum physics") 
  end


  it "should perform a search" do
    expect(@q_results.pmids.length).to be > 10
  end

  it "should handle phrases not found" do
    title = "Electron-Vibrational Coupling in the Fenna-Matthews-Olson Complex of Prosthecochloris a estuarii Determined by Temperature-Dependent Absorption and Fluorescence Line-Narrowing Measurements"
    results = PubmedAPI::Interface.search( title, {:load_all_pmids => true})
    expect(results.phrases_not_found).to eql(["estuarii"])
  end

  it "should make an API call" do
    options = PubmedAPI::Interface::DEFAULT_OPTIONS
    options = options.merge({:query => 'term=scrotum'})

    doc = PubmedAPI::Interface.make_api_request(options)
    records = doc.xpath('/eSearchResult/IdList/Id')
    count = doc.xpath('/eSearchResult/Count').first.content.to_i
    expect(count).to be > 0
    expect(records.length).to eql(count)
  end 
  

  it "should fetch a paper" do
    id = '25554862'
    title = "Completing the picture for the smallest eigenvalue of real Wishart matrices."
    url = "http://link.aps.org/abstract/PRL/v113/p250201"
    strucs = PubmedAPI::Interface.fetch_papers([id])
    paper = strucs[0]
    expect(paper.title).to eql(title)
    expect(paper.pmid).to eql(id)
    expect(paper.url).to eql(url)
  end 

  it "should fetch a journal" do
    id = '0401141'
    title = 'Physical review letters.'
    strucs = PubmedAPI::Interface.fetch_journals([id])
    j = strucs[0]
    expect(j.title_long).to eql(title)
    expect(j.nlmid).to eql(id)
  end 
 
  it "it should fix strange journal ids" do
     fixed = PubmedAPI::Interface.convert_odd_journal_ids('19620690R')
     expect(fixed).to eql('100381')
  end

  it "it should get journal id from issn" do
     fixed = PubmedAPI::Interface.get_journal_id_from_issn('1361-6633')
     expect(fixed).to eql('100381')
  end

  it "should get fulltext urls for ids" do
    ids = ["25933345","25933144","23933344"]

    hash = PubmedAPI::Interface.get_fulltext_links(ids)
    paper = hash[ids[0]][0]
    expect(paper.url).to eql('http://link.aps.org/abstract/PRL/v114/p158701')
  end 



end