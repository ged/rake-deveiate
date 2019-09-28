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

		task( gemspec_file ) do |task|
			tasklib.prompt.say "Updating gemspec"

			spec = self.make_prerelease_gemspec( tasklib )

			File.open( task.name, 'w' ) do |fh|
				fh.write( spec.to_ruby )
			end
		end

		desc "(Re)Generate the gemspec file"
		task :gemspec => gemspec_file

		CLOBBER.include( gemspec_file.to_s )
	end


	### Return a Gem::Specification created from the project's metadata.
	def make_gemspec( tasklib )
		spec = Gem::Specification.new

		spec.name         = tasklib.gemname
		spec.summary      = tasklib.extract_summary || "A gem of some sort."
		spec.description  = tasklib.extract_description || spec.summary
		spec.files        = tasklib.project_files
		spec.signing_key  = File.expand_path( "~/.gem/gem-private_key.pem" )
		spec.cert_chain   = tasklib.cert_files
		spec.version      = tasklib.version

		tasklib.dependencies.each do |dep|
			if dep.runtime?
				spec.add_runtime_dependency( dep )
			else
				spec.add_development_dependency( dep )
			end
		end

		return spec
	end


	### Return a Gem::Specification with its properties modified to be suitable for
	### a pre-release gem.
	def make_prerelease_gemspec( tasklib )
		spec = self.make_gemspec( tasklib )

		spec.version     = self.prerelease_version( tasklib )
		spec.signing_key = nil
		spec.cert_chain  = []

		return spec
	end


	### Return a version string 
	def prerelease_version( tasklib )
		return "#{tasklib.version.bump}.0.pre.#{Time.now.strftime("%Y%m%d%H%M%S")}"
	end


end # module Rake::DevEiate::Gemspec


