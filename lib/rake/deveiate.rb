# -*- ruby -*-
# frozen_string_literal: true

require 'pathname'
require 'etc'

begin
  gem 'rdoc'
rescue Gem::LoadError
end unless defined?(RDoc)

begin
  gem 'rake'
rescue Gem::LoadError
end unless defined?(Rake)


require 'rake'
require 'rake/tasklib'
require 'rdoc'
require 'rdoc/markdown'
require 'tty/prompt'
require 'tty/table'
require 'pastel'
require 'rubygems/request_set'


# A task library for maintaining an open-source library.
class Rake::DevEiate < Rake::TaskLib
	include Rake::TraceOutput

	# Pattern for extracting a version constant
	VERSION_PATTERN = /VERSION\s*=\s*(?<quote>['"])(?<version>\d+(\.\d+){2}.*)\k<quote>/

	# The version of this library
	VERSION = '0.1.0'

	# Paths
	PROJECT_DIR = Pathname.pwd

	DOCS_DIR    = PROJECT_DIR + 'docs'
	LIB_DIR     = PROJECT_DIR + 'lib'
	EXT_DIR     = PROJECT_DIR + 'ext'
	SPEC_DIR    = PROJECT_DIR + 'spec'
	DATA_DIR    = PROJECT_DIR + 'data'
	CERTS_DIR   = PROJECT_DIR + 'certs'

	DEFAULT_MANIFEST_FILE = PROJECT_DIR + 'Manifest.txt'
	DEFAULT_PROJECT_FILES =
		Rake::FileList[ "*.rdoc", "*.md", "lib/*.rb", "lib/**/*.rb", "ext/**/*.[ch]" ]

	# The file that contains the project's dependencies
	GEMDEPS_FILE = PROJECT_DIR + 'gem.deps.rb'


	# Autoload utility classes
	autoload :GemDepFinder, 'rake/deveiate/gem_dep_finder'


	### Declare an attribute that should be cast to a Pathname when set.
	def self::attr_pathname( name ) # :nodoc:
		attr_reader( name )
		define_method( "#{name}=" ) do |new_value|
			instance_variable_set( "@#{name}", Pathname(new_value) )
		end
	end


	### Set up common development tasks
	def self::setup( gemname, **options, &block )
		return self.new( gemname, **options, &block )
	end



	### Create the devEiate tasks for a gem with the given +gemname+.
	def initialize( gemname, **options, &block )
		@gemname       = validate_gemname( gemname )
		@options       = options

		@manifest_file = DEFAULT_MANIFEST_FILE.dup
		@project_files = self.read_manifest
		@version       = self.find_version
		@readme_file   = self.find_readme
		@readme        = self.parse_readme
		@rdoc_files    = @project_files.dup
		@rdoc_files.exclude( SPEC_DIR + '**', DATA_DIR + '**' )
		@cert_files    = Rake::FileList[ CERTS_DIR + '*.pem' ]
		@current_user  = Etc.getlogin

		@docs_dir      = DOCS_DIR.dup

		@title         = self.extract_default_title
		@authors       = []
		@dependencies  = self.find_dependencies

		self.instance_exec( self, &block ) if block

		self.define_default_task
		self.define_debug_tasks
		self.load_task_libraries
	end


	######
	public
	######

	##
	# The name of the gem the task will build
	attr_reader :gemname

	##
	# The Gem::Version of the current library, extracted from the top-level
	# namespace.
	attr_reader :version

	##
	# The README of the project as an RDoc::Markup::Document
	attr_reader :readme

	##
	# The title of the library for things like docs, gemspec, etc.
	attr_accessor :title

	##
	# The file that will be the main page of documentation
	attr_pathname :readme_file

	##
	# The file to read the list of distribution files from
	attr_pathname :manifest_file

	##
	# The files which should be distributed with the project as a Rake::FileList
	attr_reader :project_files

	##
	# The files which should be used to generate documentation as a Rake::FileList
	attr_reader :rdoc_files

	##
	# The public cetificates that can be used to verify signed gems
	attr_reader :cert_files

	##
	# The username of the current user
	attr_reader :current_user

	##
	# The gem's authors in the form of strings in the format: `Name <email>`
	attr_reader :authors

	##
	# The Gem::RequestSet that describes the gem's dependencies
	attr_reader :dependencies



	#
	# Task definition
	#

	### Set up a simple default task
	def define_default_task
		desc "The task that runs by default"
		task( :default => :spec )
	end


	### Set up tasks for debugging the task library.
	def define_debug_tasks
		task( :debug ) do
			self.prompt.say( self.pastel.headline "Project files:" )
			table = self.generate_project_files_table
			self.prompt.say( table.render(:unicode) )

			self.prompt.say( self.pastel.headline "Dependencies" )
			table = self.generate_dependencies_table
			self.prompt.say( table.render(:unicode) )
		end
	end


	### Load the deveiate task libraries.
	def load_task_libraries
		taskdir = Pathname( __FILE__.delete_suffix('.rb') )
		tasklibs = Rake::FileList[ taskdir + '*.rb' ].pathmap( '%-2d/%n' )

		trace( "Loading task libs: %p" % [ tasklibs ] )
		tasklibs.each do |lib|
			require( lib )
		end

		self.class.constants.
			map {|c| self.class.const_get(c) }.
			select {|c| c.respond_to?(:define_tasks) }.
			each do |mod|
				mod.define_tasks( self )
			end
	end


	#
	# Utility methods
	#

	### Fetch the TTY-Prompt, creating it if necessary.
	def prompt
		return @prompt ||= TTY::Prompt.new( output: $stderr )
	end


	### Fetch the Pastel object, creating it if necessary.
	def pastel
		return @pastel ||= begin
			pastel = Pastel.new( enabled: $stdout.tty? )
			pastel.alias_color( :headline, :bold, :white, :on_black )
			pastel.alias_color( :success, :bold, :green )
			pastel.alias_color( :error, :bold, :red )
			pastel.alias_color( :warning, :yellow )
			pastel.alias_color( :added, :green )
			pastel.alias_color( :removed, :red )
			pastel.alias_color( :prompt, :cyan )
			pastel.alias_color( :even_row, :bold )
			pastel.alias_color( :odd_row, :reset )
			pastel
		end
	end


	### Extract the default title from the README if possible, or derive it from the
	### gem name.
	def extract_default_title
		title = self.readme&.table_of_contents.first.text
		title ||= self.name
	end


	### Extract a summary from the README if possible. Returns +nil+ if not.
	def extract_summary
		return self.extract_description&.split( /(?<=\.)\s+/ ).first
	end


	### Extract a description from the README if possible. Returns +nil+ if not.
	def extract_description
		return self.readme&.parts.find {|part| part.is_a?(RDoc::Markup::Paragraph) }&.text
	end


	### Find the file that contains the VERSION constant and return it as a
	### Gem::Version.
	def find_version
		version_file = LIB_DIR + "%s.rb" % [ self.gemname.gsub(/-/, '/') ]
		raise "Version could not be read from %s" % [version_file] unless version_file.readable?

		version_line = version_file.readlines.find {|l| l =~ VERSION_PATTERN } or
			abort "Can't read the VERSION from #{version_file}!"
		version = version_line[ VERSION_PATTERN, :version ] or
			abort "Couldn't find a semantic version in %p" % [ version_line ]

		return Gem::Version.new( version )
	end


	### Returns +true+ if the manifest file exists and is readable.
	def has_manifest?
		return self.manifest_file.readable?
	end


	### Read the manifest file if there is one, falling back to a default list if
	### there isn't a manifest.
	def read_manifest
		if self.has_manifest?
			entries = self.manifest_file.readlines.map( &:chomp )
			return Rake::FileList[ *entries ]
		else
			warn "No manifest (%s): falling back to a default list" % [ self.manifest_file ]
			return DEFAULT_PROJECT_FILES.dup
		end
	end


	### Find the README file in the list of project files and return it as a
	### Pathname.
	def find_readme
		file = self.project_files.find {|file| file =~ /^README\.(md|rdoc)$/ } or
			raise "No README found in the project files."
		return Pathname( file )
	end


	### Generate a TTY::Table from the current project files and return it.
	def generate_project_files_table
		columns = [
			self.project_files.sort,
			self.rdoc_files.sort
		]
		table = TTY::Table.new(
			header: ['Project', 'Docs'],
			rows: columns.transpose,
		)

		return table
	end


	### Generate a TTY::Table from the current dependency list and return it.
	def generate_dependencies_table
		table = TTY::Table.new( header: ['Gem', 'Version', 'Dev'] )
		self.dependencies.specs.each do |spec|
			table << [ spec.name, spec.version]
		end
	end


	### Parse the README into an RDoc::Markup::Document and return it
	def parse_readme
		case self.readme_file.extname
		when '.md'
			return RDoc::Markdown.parse( self.readme_file.read )
		when '.rdoc'
			return RDoc::Format.parse( self.readme_file.read )
		else
			raise "Can't parse %s: unhandled format %p" % [ self.readme_file, README_FILE.extname ]
		end
	end


	### Load the gemdeps file if it exists, and return a Gem::RequestSet with the
	### regular dependencies contained in it.
	def find_dependencies
		finder = Rake::DevEiate::GemDepFinder.new( GEMDEPS_FILE )
		finder.load
		return finder.dependencies
	end


	#######
	private
	#######

	### Output +args+ to $stderr if tracing is enabled.
	def trace( *args )
		Rake.application.trace( *args ) if Rake.application.options.trace
	end


	### Ensure the given +gemname+ is valid, raising if it isn't.
	def validate_gemname( gemname )
		raise ScriptError, "invalid gem name" unless
			Gem::SpecificationPolicy::VALID_NAME_PATTERN.match?( gemname )
		return gemname.freeze
	end

end # class Rake::DevEiate
