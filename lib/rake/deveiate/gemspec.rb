# -*- ruby -*-
# frozen_string_literal: true

require 'etc'
require 'rubygems'
require 'rake'
require 'rake/clean'
require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Gemspec-generation tasks
module Rake::DevEiate::Gemspec
	extend Rake::DSL

	# Pattern for splitting parsed authors list items into name and email
	AUTHOR_PATTERN = /^(?<name>.*)\s<(?<email>.*)>$/


	### Define gemspec tasks
	def define_tasks
		super if defined?( super )

		gemspec_file = "#{self.name}.gemspec"

		if self.has_manifest?
			file( self.manifest_file )
			file( gemspec_file => self.manifest_file )
		else
			file( gemspec_file )
		end

		task( gemspec_file ) do |task|
			self.prompt.say "Updating gemspec"

			spec = self.make_prerelease_gemspec

			File.open( task.name, 'w' ) do |fh|
				fh.write( spec.to_ruby )
			end
		end

		desc "(Re)Generate the gemspec file"
		task :gemspec => gemspec_file

		CLEAN.include( gemspec_file.to_s )
	end


	### Return a Gem::Specification created from the project's metadata.
	def make_gemspec
		spec = Gem::Specification.new

		spec.name         = self.name
		spec.description  = self.description
		spec.summary      = self.summary || self.extract_summary
		spec.files        = self.project_files
		spec.signing_key  = File.expand_path( "~/.gem/gem-private_key.pem" )
		spec.cert_chain   = self.cert_files
		spec.version      = self.version
		spec.licenses     = self.licenses
		spec.date         = Date.today

		self.authors.each do |author|
			if ( m = author.match(AUTHOR_PATTERN) )
				spec.authors ||= []
				spec.authors << m[:name]
				spec.email ||= []
				spec.email << m[:email] if m[:email]
			else
				self.prompt.warn "Couldn't extract author name + email from %p" % [ author ]
			end
		end

		self.dependencies.each do |dep|
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
	def make_prerelease_gemspec
		spec = self.make_gemspec

		spec.version     = self.prerelease_version
		spec.signing_key = nil
		spec.cert_chain  = []

		return spec
	end


	### Return a version string 
	def prerelease_version
		return "#{self.version.bump}.0.pre.#{Time.now.strftime("%Y%m%d%H%M%S")}"
	end


end # module Rake::DevEiate::Gemspec


