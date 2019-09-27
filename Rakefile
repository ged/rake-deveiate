#!/usr/bin/env ruby -S rake

require 'pathname'

require 'rake/clean'
require 'rspec/core/rake_task'

# Dogfood
$LOAD_PATH.unshift( 'lib' )
require 'rake/deveiate'

Rake::DevEiate.setup( 'rake-deveiate' ) do |gem|
	gem.title = 'Rake Tasks for DevEiate Libraries'
end


