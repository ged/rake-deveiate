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

	# Environment variable for overriding the name of the user packaging up a
	# release.
	RELEASE_USER_ENV = 'RELEASE_USER'


	##
	# The path to the file used to sign released gems
	attr_accessor :signing_key


	### Set some defaults when the task lib is set up.
	def setup( _name, **options )
		super if defined?( super )

		@signing_key = options[:signing_key] || Gem.default_key_path
		@post_install_message = options[:post_install_message]

		@gemspec = nil
	end


	##
	# A message to be displayed after the gem is installed.
	attr_accessor :post_install_message


	### Reset any cached data when project attributes change.
	def reset
		super if defined?( super )
		@gemspec = nil
		@post_install_message = nil
	end


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

		task :precheckin => :gemspec

		task( :gemspec_debug, &method(:do_gemspec_debug) )
		task :debug => :gemspec_debug
	end


	### Task function -- output debugging for gemspec tasks.
	def do_gemspec_debug( task, args )
		gemspec = self.gemspec
		gemspec_src = gemspec.to_yaml

		if self.post_install_message
			self.prompt.say( "Post-install message:", color: :bright_green )
			self.prompt.say( self.indent(self.post_install_message, 4) )
			self.prompt.say( "\n" )
		end

		self.prompt.say( "Gemspec:", color: :bright_green )
		self.prompt.say( self.indent(gemspec_src, 4) )
		self.prompt.say( "\n" )
	end


	### Return the project's Gem::Specification, creating it if necessary.
	def gemspec
		return @gemspec ||= self.make_gemspec
	end


	### Validate the gemspec, raising a Gem::InvalidSpecificationException if it's
	### not valid.
	def validate_gemspec( packaging=true, strict=false )
		return self.gemspec.validate( packaging, strict )
	end


	### Return a Gem::Specification created from the project's metadata.
	def make_gemspec
		spec = Gem::Specification.new

		spec.name         = self.name
		spec.description  = self.description
		spec.homepage     = self.homepage
		spec.summary      = self.summary || self.extract_summary
		spec.files        = self.project_files
		spec.executables  = self.executables
		spec.extensions   = self.extensions.to_a
		spec.signing_key  = self.resolve_signing_key.to_s
		spec.cert_chain   = [ self.find_signing_cert ].compact
		spec.version      = self.version
		spec.licenses     = self.licenses
		spec.date         = Date.today

		spec.metadata     = self.make_gem_metadata

		spec.required_ruby_version = self.required_ruby_version if
			self.required_ruby_version
		spec.metadata['allowed_push_host'] = self.allowed_push_host if self.allowed_push_host
		spec.post_install_message = self.post_install_message

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


	### Build the hash of metadata that should be attached to the gem.
	def make_gem_metadata
	    # "bug_tracker_uri"   => "https://example.com/user/bestgemever/issues",
	    # "changelog_uri"     => "https://example.com/user/bestgemever/CHANGELOG.md",
	    # "documentation_uri" => "https://www.example.info/gems/bestgemever/0.0.1",
	    # "homepage_uri"      => "https://bestgemever.example.io",
	    # "mailing_list_uri"  => "https://groups.example.com/bestgemever",
	    # "source_code_uri"   => "https://example.com/user/bestgemever",
	    # "wiki_uri"          => "https://example.com/user/bestgemever/wiki"

		metadata = {
			"homepage_uri" => self.homepage
		}

		if docs_uri = self.extract_documentation_uri
			metadata['documentation_uri'] = docs_uri.to_s
			if docs_uri.path.end_with?( '/', self.name )
				cl_uri = docs_uri.dup
				cl_uri.path = File.join( cl_uri.path, 'History_md.html' )
				metadata['changelog_uri'] = cl_uri.to_s
			end
		end

		if source_uri = self.extract_source_uri
			metadata['source_uri'] = source_uri.to_s
			case source_uri.host
			when /\.sr\.ht/
				bt_uri = source_uri.dup
				bt_uri.host = 'todo.sr.ht'
				metadata['bug_tracker_uri'] = bt_uri.to_s
			when /\.gitlab\.com/
				bt_uri = source_uri.dup
				bt_uri.path += '-/issues'
				metadata['bug_tracker_uri'] = bt_uri.to_s
			when /\.github\.com/
				bt_uri = source_uri.dup
				bt_uri.path += '/issues'
				metadata['bug_tracker_uri'] = bt_uri.to_s
			else
				self.trace "No idea what bug tracker URIs for %s look like!" % [ source_uri.host ]
			end
		end

		return metadata
	end


	### Extract the documentation URI from the `docs` item of the first NOTE-type
	### list in the README. Returns +nil+ if no such URI could be found.
	def extract_documentation_uri
		return fail_extraction( :documentation, "no README" ) unless self.readme

		list = self.readme.parts.find {|part| RDoc::Markup::List === part && part.type == :NOTE } or
			return fail_extraction(:documentation, "No NOTE list")
		item = list.items.find {|item| item.label.include?('docs') } or
			return fail_extraction(:documentation, "No `docs` item")

		return URI( item.parts.first.text )
	end


	### Extract the source URI from the `docs` item of the first NOTE-type
	### list in the README. Returns +nil+ if no such URI could be found.
	def extract_source_uri
		return fail_extraction( :source, "no README" ) unless self.readme

		list = self.readme.parts.find {|part| RDoc::Markup::List === part && part.type == :NOTE } or
			return fail_extraction(:code, "No NOTE list")
		item = list.items.find {|item| item.label.include?('code') } or
			return fail_extraction(:code, "No `code` item")

		return URI( item.parts.first.text )
	end


	### Return a version string
	def prerelease_version
		return "#{self.version.bump}.0.pre.#{Time.now.strftime("%Y%m%d%H%M%S")}"
	end


	### Resolve the path of the signing key
	def resolve_signing_key
		path = Pathname( self.signing_key ).expand_path
		path = path.readlink if path.symlink?
		return path
	end


	### Return the path to the cert belonging to the user packaging up the release.
	### Returns nil if no such cert exists.
	def find_signing_cert
		current_user = ENV[ RELEASE_USER_ENV ] || Etc.getlogin
		certfile = self.cert_files.find {|fn| fn.end_with?("#{current_user}.pem") } or
			return nil
		return File.expand_path( certfile )
	end

end # module Rake::DevEiate::Gemspec


