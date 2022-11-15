# -*- ruby -*-
# frozen_string_literal: true

require 'rake'
require 'rake/phony'
require 'rdoc/task'

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Documentation-generation tasks
module Rake::DevEiate::Docs
	extend Rake::DSL


	### Define documentation tasks
	def define_tasks
		super if defined?( super )

		task :docs => :phony

		RDoc::Task.new( 'docs' ) do |rdoc|
			rdoc.main = self.readme_file.to_s
			rdoc.rdoc_files = self.rdoc_files
			rdoc.generator = self.rdoc_generator
			rdoc.title = self.title
			rdoc.rdoc_dir = Rake::DevEiate::DOCS_DIR.to_s
		end

		if self.publish_to
			target = self.publish_to

			desc "Publish API docs to #{target}"
			task :publish_docs => :docs do
				target = File.join( target, self.name ) unless target.end_with?( self.name )
				sh 'rsync', '-COva', Rake::DevEiate::DOCS_DIR.to_s + '/', target
			end
		end

		task :debug => :docs_debug
		task( :docs_debug, &method(:do_docs_debug) )
	end


	### Task body for the :docs_debug task
	def do_docs_debug( task, args )
		self.prompt.say( "Docs are published to:", color: :bright_green )
		if ( publish_url = self.publish_to )
			self.prompt.say( self.indent(publish_url, 4) )
		else
			self.prompt.say( self.indent("n/a"), color: :bright_yellow )
		end
		self.prompt.say( "\n" )
	end

end # module Rake::DevEiate::Docs


