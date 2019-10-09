# -*- ruby -*-
# frozen_string_literal: true

$LOAD_PATH.unshift( 'lib' )

require 'rake/deveiate'
require 'hglib'

tasklib = Rake::DevEiate.setup( 'rake-deveiate' )
puts "Tasklib is in `tasklib`"

