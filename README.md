# PubmedApi

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pubmed_api'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pubmed_api

## Usage

This is a work in progress. But you can use it 

To search for papers:

results = PubmedAPI::Interface.search("quantum physics") 
results.pmids gives you a list of the matching pubmed ids

To get a paper:

strucs = PubmedAPI::Interface.fetch_papers([id])
paper = struc[0]
paper.title = "A paper title"
paper.url = "http://alinktofulltext.com"

Look in the spec for further examples 

## Contributing

1. Fork it ( https://github.com/[my-github-username]/pubmed_api/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
