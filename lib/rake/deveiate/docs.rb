# -*- ruby -*-
# frozen_string_literal: true

require 'rake'
require 'rake/phony'
require 'rdoc/task'

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Documentation-generation tasks
module Rake::DevEiate::Docs
	extend Rake::DSL


	###############
	module_function
	###############

	### Define documentation tasks
	def define_tasks( tasklib )
		task :docs => :phony

		RDoc::Task.new( 'docs' ) do |rdoc|
			rdoc.main = tasklib.readme_file.to_s
			rdoc.rdoc_files = tasklib.rdoc_files
			rdoc.generator = :fivefish
			rdoc.title = tasklib.title
			rdoc.rdoc_dir = Rake::DevEiate::DOCS_DIR.to_s
		end

	end

end # module Rake::DevEiate::Docs


