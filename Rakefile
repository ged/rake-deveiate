#!/usr/bin/env ruby -S rake

require 'pathname'

require 'rake/clean'
require 'rspec/core/rake_task'

# Dogfood
$LOAD_PATH.unshift( 'lib', '../hglib/lib' )
require 'rake/deveiate'

Rake::DevEiate.setup( 'rake-deveiate' ) do |project|
	project.publish_to = 'deveiate:/usr/local/www/public/code'
end


