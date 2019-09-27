# -*- ruby -*-
# frozen_string_literal: true

require 'rdoc/task'
require 'rake/deveiate' unless defined?( Rake::DevEiate )

module Rake::DevEiate::Docs

	### Define documentation tasks
	def self::define_tasks( tasklib )

		RDoc::Task.new( 'docs' ) do |rdoc|
			rdoc.main = Rake::DevEiate::README_FILES.first
			rdoc.rdoc_files = Rake::DevEiate::RDOC_FILES
			rdoc.generator = :fivefish
			rdoc.title = tasklib.title
			rdoc.rdoc_dir = Rake::DevEiate::DOCS_DIR.to_s
		end

	end

end # module Rake::DevEiate::Docs


