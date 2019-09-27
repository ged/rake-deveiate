# -*- ruby -*-
# frozen_string_literal: true

require 'etc'
require 'rubygems'
require 'rake'
require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Gemspec-generation tasks
module Rake::DevEiate::Gemspec
	extend Rake::DSL


	###############
	module_function
	###############

	### Define gemspec tasks
	def define_tasks( tasklib )

		gemspec_file = "#{tasklib.gemname}.gemspec"

		if tasklib.has_manifest?
			file( tasklib.manifest_file )
			file( gemspec_file => tasklib.manifest_file )
		else
			file( gemspec_file )
		end

		desc "(Re)Generate the gemspec file"
		task( gemspec_file ) do |task|
			tasklib.prompt.say "Updating gemspec"
			spec = Gem::Specification.new

			spec.files = tasklib.project_files
			spec.signing_key = nil
			spec.cert_chain = tasklib.cert_files
			spec.version = self.prerelease_version( tasklib )

			File.open( task.name, 'w' ) do |fh|
				fh.write( spec.to_ruby )
			end
		end

		task :gemspec => gemspec_file

		CLOBBER.include( gemspec_file.to_s )
	end


	### Return a version string 
	def prerelease_version( tasklib )
		return "#{tasklib.version.bump}.0.pre.#{Time.now.strftime("%Y%m%d%H%M%S")}"
	end

end # module Rake::DevEiate::Gemspec


