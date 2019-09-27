# -*- ruby -*-
# frozen_string_literal: true

require 'pathname'

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


# A task library for maintaining an open-source library.
class Rake::DevEiate < Rake::TaskLib
	include Rake::TraceOutput


	PROJECT_DIR = Pathname.pwd

	DOCS_DIR = PROJECT_DIR + 'docs'
	LIB_DIR = PROJECT_DIR + 'lib'
	EXT_DIR = PROJECT_DIR + 'ext'
	SPEC_DIR = PROJECT_DIR + 'spec'

	DEFAULT_MANIFEST_FILE = PROJECT_DIR + 'Manifest.txt'
	DEFAULT_PROJECT_FILES =
		Rake::FileList[ "*.rdoc", "*.md", "lib/*.rb", "lib/**/*.rb", "ext/**/*.[ch]" ]


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
		@readme_file   = self.find_readme
		@readme        = self.parse_readme( **options )
		@title         = self.extract_default_title
		@rdoc_files    = @project_files.dup
		@rdoc_files.exclude( 'spec/**', 'data/**' )

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
			self.prompt.say( table )
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


	### Read the manifest file if there is one, falling back to a default list if
	### there isn't a manifest.
	def read_manifest
		if self.manifest_file.readable?
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

		return table.render( :unicode )
	end


	### Parse the README into an RDoc::Markup::Document and return it
	def parse_readme( **options )
		case self.readme_file.extname
		when '.md'
			return RDoc::Markdown.parse( self.readme_file.read )
		when '.rdoc'
			return RDoc::Format.parse( self.readme_file.read )
		else
			raise "Can't parse %s: unhandled format %p" % [ self.readme_file, README_FILE.extname ]
		end
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
