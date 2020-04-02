# Install with `gem install -Ng`

source 'https://rubygems.org'

gem 'rake', '~> 13.0'
gem 'rdoc', '~> 6.2'
gem 'rspec', '~> 3.8'
gem 'simplecov', '~> 0.18'
gem 'hglib', '~> 0.10', '>= 0.10.1'
gem 'tty-prompt', '~> 0.19'
gem 'tty-editor', '~> 0.5'
gem 'tty-table', '~> 0.11'
gem 'pastel', '~> 0.7'

group :development do
	gem 'rdoc-generator-fivefish', '~> 0.4'
end

