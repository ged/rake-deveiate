# -*- ruby -*-
# frozen_string_literal: true

require 'pathname'
require 'etc'
require 'tempfile'

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
require 'rake/clean'
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
	VERSION = '0.23.0'

	# The server to release to by default
	DEFAULT_GEMSERVER = 'https://rubygems.org/'

	# What to use for the homepage if none is set
	DEFAULT_HOMEPAGE = 'https://example.com/'

	# The description to use if none is set
	DEFAULT_DESCRIPTION = "A gem of some sort."

	# The version to use if one cannot be read from the source
	DEFAULT_VERSION = '0.1.0'

	# The prefix to use for release version tags by default
	DEFAULT_RELEASE_TAG_PREFIX = 'v'

	# Words in the package/gem name that should not be included in deriving paths,
	# file names, etc.
	PACKAGE_IGNORE_WORDS = %w[ruby]

	# Paths
	PROJECT_DIR  = Pathname( '.' )

	DOCS_DIR     = PROJECT_DIR + 'docs'
	LIB_DIR      = PROJECT_DIR + 'lib'
	EXT_DIR      = PROJECT_DIR + 'ext'
	SPEC_DIR     = PROJECT_DIR + 'spec'
	INT_SPEC_DIR = PROJECT_DIR + 'integration'
	DATA_DIR     = PROJECT_DIR + 'data'
	CERTS_DIR    = PROJECT_DIR + 'certs'
	PKG_DIR      = PROJECT_DIR + 'pkg'
	CHECKSUM_DIR = PROJECT_DIR + 'checksum'

	DEFAULT_MANIFEST_FILE = PROJECT_DIR + 'Manifest.txt'
	DEFAULT_README_FILE = PROJECT_DIR + 'README.md'
	DEFAULT_HISTORY_FILE = PROJECT_DIR + 'History.md'

	DEFAULT_PROJECT_FILES = Rake::FileList[
		'*.{rdoc,md,txt}',
		'bin/*',
		'lib/**/*.rb',
		'ext/*.[ch]', 'ext/**/*.[ch]',
		'data/**/*',
		'spec/**/*.rb',
	]
	DEFAULT_PROJECT_FILES.exclude( 'Manifest*.txt' )

	# Environment variable overrides for settings
	ENV_SETTING_NAME = {
		version_from: 'VERSION_FROM',
	}


	# The default license for the project in SPDX form: https://spdx.org/licenses
	DEFAULT_LICENSE = 'BSD-3-Clause'

	# The file that contains the project's dependencies
	GEMDEPS_FILE = PROJECT_DIR + 'gem.deps.rb'

	# The file suffixes to include in documentation
	DOCUMENTATION_SUFFIXES = %w[
		.rb
		.c
		.h
		.md
		.rdoc
		.txt
		.png
		.jpg
		.gif
		.svg
	]

	# The path to the data directory
	DEVEIATE_DATADIR = if ENV['DEVEIATE_DATADIR']
			Pathname( ENV['DEVEIATE_DATADIR'] )
		elsif Gem.loaded_specs['rake-deveiate'] &&
		      File.directory?( Gem.loaded_specs['rake-deveiate'].datadir )
			Pathname( Gem.loaded_specs['rake-deveiate'].datadir )
		else
			Pathname( __FILE__ ).dirname.parent.parent + 'data/rake-deveiate'
		end


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
	def self::setup( name, **options, &block )
		tasklib = self.new( name, **options, &block )
		tasklib.define_tasks
		return tasklib
	end


	### Returns +true+ if Rake::DevEiate has already been set up.
	def self::already_setup?
		Rake::Task.task_defined?( 'deveiate' )
	end


	### Create the devEiate tasks for a gem with the given +name+.
	def initialize( name, **options, &block )
		@name                  = validate_gemname( name )
		@options               = options

		@rakefile              = PROJECT_DIR + 'Rakefile'
		@manifest_file         = DEFAULT_MANIFEST_FILE.dup
		@project_files         = self.read_manifest
		@executables           = self.find_executables
		@readme_file           = self.find_readme
		@history_file          = self.find_history_file
		@readme                = self.parse_readme
		@rdoc_files            = self.make_rdoc_filelist
		@rdoc_generator        = :sixfish
		@cert_files            = Rake::FileList[ CERTS_DIR + '*.pem' ]
		@licenses              = [ DEFAULT_LICENSE ]
		@version_from          = env( :version_from, as_pathname: true ) ||
			LIB_DIR + "%s.rb" % [ version_file_from(name) ]
		@release_tag_prefix    = DEFAULT_RELEASE_TAG_PREFIX

		@docs_dir              = DOCS_DIR.dup

		@title                 = self.extract_default_title
		@authors               = self.extract_authors
		@homepage              = self.extract_homepage
		@description           = self.extract_description || DEFAULT_DESCRIPTION
		@summary               = nil
		@dependencies          = self.find_dependencies
		@extensions            = Rake::FileList.new

		@default_manifest      = DEFAULT_PROJECT_FILES.dup

		@version               = nil
		@publish_to            = nil
		@required_ruby_version = nil

		super()

		self.load_task_libraries

		if block
			if block.arity.nonzero?
				block.call( self )
			else
				self.instance_exec( self, &block )
			end
		end
	end


	######
	public
	######

	##
	# The name of the gem the task will build
	attr_reader :name

	##
	# The options Hash the task lib was created with
	attr_reader :options

	##
	# The descriotion of the gem
	attr_accessor :description

	##
	# The summary description of the gem.
	attr_accessor :summary

	##
	# The README of the project as an RDoc::Markup::Document
	attr_accessor :readme

	##
	# The title of the library for things like docs, gemspec, etc.
	attr_accessor :title

	##
	# The pathname of the file to read the version from
	attr_pathname :version_from

	##
	# The project's Rakefile
	attr_pathname :rakefile

	##
	# The file that will be the main page of documentation
	attr_pathname :readme_file

	##
	# The file that provides high-level change history
	attr_pathname :history_file

	##
	# The file to read the list of distribution files from
	attr_pathname :manifest_file

	##
	# The files which should be distributed with the project as a Rake::FileList
	attr_accessor :project_files

	##
	# The Array of project files that are in the bin/ directory and are executable.
	attr_reader :executables

	##
	# The files which should be used to generate documentation as a Rake::FileList
	attr_accessor :rdoc_files

	##
	# The name of the RDoc generator to use (assumes any necessary dependencies are
	# installed)
	attr_accessor :rdoc_generator

	##
	# The public cetificates that can be used to verify signed gems
	attr_accessor :cert_files

	##
	# The licenses the project is distributed under; usual practice is to list the
	# SPDX name: https://spdx.org/licenses
	attr_accessor :licenses

	##
	# The gem's authors in the form of strings in the format: `Name <email>`
	attr_accessor :authors

	##
	# The URI of the project's homepage as a String
	attr_accessor :homepage

	##
	# The Gem::RequestSet that describes the gem's dependencies
	attr_accessor :dependencies

	##
	# A FileMap of the paths to this project's extension config scripts.
	attr_reader :extensions

	##
	# The gemserver to push gems to
	attr_accessor :allowed_push_host

	##
	# An alternative key to use for pushing gems (private gemserver)
	attr_accessor :gem_push_key

	##
	# The rsync-compatible target to publish documentation to.
	attr_accessor :publish_to

	##
	# The version of Ruby required by this gem, in Gem version format.
	attr_accessor :required_ruby_version

	##
	# The prefix to use for version tags
	attr_accessor :release_tag_prefix

	##
	# The name of the branch to release from
	attr_accessor :release_branch

	##
	# The Rake::FileList that's used in lieu of the manifest file if it
	# isn't present.
	attr_accessor :default_manifest


	#
	# Task definition
	#

	### Load the deveiate task libraries.
	def load_task_libraries
		taskdir = Pathname( __FILE__.delete_suffix('.rb') )
		tasklibs = Rake::FileList[ taskdir + '*.rb' ].pathmap( '%-2d/%n' )

		self.trace( "Loading task libs: %p" % [ tasklibs ] )
		tasklibs.each do |lib|
			require( lib )
		end

		self.class.constants.
			map {|c| self.class.const_get(c) }.
			select {|c| c.respond_to?(:instance_methods) }.
			select {|c| c.instance_methods(false).include?(:define_tasks) }.
			each do |mod|
				self.trace "Loading tasks from %p" % [ mod ]
				extend( mod )
			end

		self.setup( self.name, **self.options )
	end


	### Post-loading callback.
	def setup( name, **options )
		# No-op
	end


	### Task-definition hook.
	def define_tasks
		self.define_default_tasks
		self.define_debug_tasks

		super if defined?( super )
	end


	### Set up a simple default task
	def define_default_tasks

		# task used to indicate that rake-deveiate has already been setup once; for
		# global rakefiles.
		task :deveiate do
			# no-op
		end

		desc "The task that runs by default"
		task( :default => :spec )

		desc "Check in the current changes"
		task :checkin => [ :precheckin, :check, :test ]
		task :commit => :checkin
		task :ci => :checkin
		task :precheckin

		desc "Sanity-check the project"
		task :check

		desc "Update the history file"
		task :update_history

		desc "Package up and push a release"
		task :release => [ :prerelease, :gem, :release_gem, :postrelease ]
		task :prerelease
		task :release_gem
		task :postrelease

		desc "Run all the project's tests"
		task :test
		task :spec
		task :integration

		desc "Set up the project for development"
		task :setup do
			self.install_dependencies
		end

		desc "Turn on maintainer mode: build with extra warnings and debugging"
		task :maint do
			ENV['MAINTAINER_MODE'] = 'yes'
		end

	end


	### Set up tasks for debugging the task library.
	def define_debug_tasks
		task( :base_debug ) do
			self.output_documentation_debugging
			self.output_project_files_debugging
			self.output_dependency_debugging
		end

		task :debug => :base_debug
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


	### Output +args+ to $stderr if tracing is enabled.
	def trace( *args )
		Rake.application.trace( *args ) if Rake.application.options.trace
	end


	### Extract the default title from the README if possible, or derive it from the
	### gem name.
	def extract_default_title
		return self.name unless self.readme&.table_of_contents&.first
		title = self.readme.table_of_contents.first.text
		title ||= self.name
	end


	### Extract a summary from the README if possible. Returns +nil+ if not.
	def extract_summary
		return self.description.split( /(?<=\.)\s+/ ).first&.gsub( /\n/, ' ' )
	end


	### Extract a description from the README if possible. Returns +nil+ if not.
	def extract_description
		parts = self.readme&.parts or return nil
		desc_para = parts.find {|part| part.is_a?(RDoc::Markup::Paragraph) }&.text or return nil
		formatter = RDoc::Markup::ToHtml.new( RDoc::Options.new )
		html = formatter.convert( desc_para )

		return html.gsub( /<.*?>/, '' ).strip
	end


	### Return just the name parts of the library's authors setting.
	def author_names
		return self.authors.map do |author|
			author[ /^(.*?) </, 1 ]
		end
	end


	### Extract authors in the form `Firstname Lastname <email@address>` from the README.
	def extract_authors
		readme = self.readme or return []
		content = readme.parts.grep_v( RDoc::Markup::BlankLine )

		heading, list = content.each_cons( 2 ).find do |heading, list|
			heading.is_a?( RDoc::Markup::Heading ) &&
				heading.text =~ /^(author|maintainer)s?/i &&
				list.is_a?( RDoc::Markup::List )
		end

		unless list
			self.trace "Couldn't find an Author(s) section of the readme."
			return []
		end

		return list.items.map do |item|
			# unparse the name + email
			raw = item.parts.first.text or next
			name, email = raw.split( ' mailto:', 2 )
			if email
				"%s <%s>" % [ name, email ]
			else
				name
			end
		end
	end


	### Extract the URI of the homepage from the `home` item of the first NOTE-type
	### list in the README. Returns +nil+ if no such URI could be found.
	def extract_homepage
		return fail_extraction( :homepage, "no README" ) unless self.readme

		list = self.readme.parts.find {|part| RDoc::Markup::List === part && part.type == :NOTE } or
			return fail_extraction(:homepage, "No NOTE list")
		item = list.items.find {|item| item.label.include?('home') } or
			return fail_extraction(:homepage, "No `home` item")

		return item.parts.first.text
	end


	### Return an Array of the paths for the executables contained in the project files.
	def find_executables
		paths = self.project_files.find_all do |path|
			path.start_with?( 'bin/' )
		end
		return paths.map {|path| path[%r{^bin/(.*)}, 1] }
	end


	### Return the project version as a Gem::Version, reading it from the
	### #version_from file if it's not set yet.
	def version
		return @version ||= self.find_version
	end


	### Find the file that contains the VERSION constant and return it as a
	### Gem::Version.
	def find_version
		version_file = self.version_from

		unless version_file.readable?
			self.prompt.warn "Version could not be read from %s" % [ version_file ]
			return nil
		end

		version_line = version_file.readlines.find {|l| l =~ VERSION_PATTERN } or
			abort "Can't read the VERSION from #{version_file}!"
		version = version_line[ VERSION_PATTERN, :version ] or
			abort "Couldn't find a semantic version in %p" % [ version_line ]

		return Gem::Version.new( version )
	end


	### Return a Regexp that matches the project's convention for versions.
	def release_tag_pattern
		prefix = self.release_tag_prefix
		return /#{prefix}\d+(\.\d+)+/
	end


	### Fetch the list of the versions of releases that have entries in the history
	### file.
	def get_history_file_versions
		tag_pattern = self.release_tag_pattern

		return IO.readlines( self.history_file ).grep( tag_pattern ).map do |line|
			line[ /^(?:h\d\.|#+|=+)\s+(#{tag_pattern})\s+/, 1 ]
		end.compact
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
			self.prompt.warn "No manifest (%s): falling back to a default list" %
				[ self.manifest_file ]
			return self.default_manifest
		end
	end


	### Make a Rake::FileList of the files that should be used to generate
	### documentation.
	def make_rdoc_filelist
		list = self.project_files.dup

		list.exclude do |fn|
			fn =~ %r:^(spec|data)/: || !fn.end_with?( *DOCUMENTATION_SUFFIXES )
		end

		return list
	end


	### Find the README file in the list of project files and return it as a
	### Pathname.
	def find_readme
		file = self.project_files.find {|file| file =~ /^README\.(md|rdoc)$/ }
		if file
			return Pathname( file )
		else
			self.prompt.warn "No README found in the project files."
			return DEFAULT_README_FILE
		end
	end


	### Find the history file in the list of project files and return it as a
	### Pathname.
	def find_history_file
		file = self.project_files.find {|file| file =~ /^History\.(md|rdoc)$/ }
		if file
			return Pathname( file )
		else
			self.prompt.warn "No History.{md,rdoc} found in the project files."
			return DEFAULT_HISTORY_FILE
		end
	end


	### Generate a TTY::Table from the current project files and return it.
	def generate_project_files_table
		columns = [
			self.project_files.sort,
			self.rdoc_files.sort
		]

		max_length = columns.map( &:length ).max
		columns.each do |col|
			self.trace "Filling out columns %d-%d" % [ col.length, max_length ]
			next if col.length == max_length
			col.fill( '', col.length .. max_length - 1 )
		end

		table = TTY::Table.new(
			header: ['Project', 'Documentation'],
			rows: columns.transpose,
		)

		return table
	end


	### Generate a TTY::Table from the current dependency list and return it.
	def generate_dependencies_table
		table = TTY::Table.new( header: ['Gem', 'Version', 'Type'] )

		self.dependencies.each do |dep|
			table << [ dep.name, dep.requirement.to_s, dep.type ]
		end

		return table
	end


	### Parse the README into an RDoc::Markup::Document and return it
	def parse_readme
		return nil unless self.readme_file.readable?

		case self.readme_file.extname
		when '.md'
			return RDoc::Markdown.parse( self.readme_file.read )
		when '.rdoc'
			return RDoc::Markup.parse( self.readme_file.read )
		else
			raise "Can't parse %s: unhandled format %p" % [ self.readme_file, README_FILE.extname ]
		end
	end


	### Load the gemdeps file if it exists, and return a Gem::RequestSet with the
	### regular dependencies contained in it.
	def find_dependencies
		unless GEMDEPS_FILE.readable?
			self.prompt.warn "Deps file (%s) is missing or unreadable, assuming no dependencies." %
				[ GEMDEPS_FILE ]
			return []
		end

		finder = Rake::DevEiate::GemDepFinder.new( GEMDEPS_FILE )
		finder.load
		return finder.dependencies
	end


	### Install the gems listed in the gem dependencies file.
	def install_dependencies
		self.prompt.say "Installing dependencies"
		ruby '-S', 'gem', 'i', '-Ng'
	end


	### Return the character used to build headings give the filename of the file to
	### be generated.
	def header_char_for( filename )
		case File.extname( filename )
		when '.md' then return '#'
		when '.rdoc' then return '='
		when ''
			if filename == 'Rakefile'
				return '#'
			end
		end

		raise "Don't know what header character is appropriate for %s" % [ filename ]
	end


	### Read a template with the given +name+ from the data directory and return it
	### as an ERB object.
	def read_template( name )
		name = "%s.erb" % [ name ] unless name.to_s.end_with?( '.erb' )
		template_path = DEVEIATE_DATADIR + name
		template_src = template_path.read( encoding: 'utf-8' )

		return ERB.new( template_src, trim_mode: '-' )
	end


	### Load the template at the specified +template_path+, and render it with suitable
	### settings for the given +target_filename+.
	def load_and_render_template( template_path, target_filename )
		template = self.read_template( template_path )
		header_char = self.header_char_for( target_filename )

		return template.result_with_hash(
			header_char: header_char,
			project: self
		)
	end


	### Yield an IO to the block open to a file that will replace +filename+ if the
	### block returns successfully.
	def write_replacement_file( filename, **opts )
		path = Pathname( filename ).expand_path
		mode = path.stat.mode
		owner = path.stat.uid
		group = path.stat.gid

		tmpfile = Tempfile.create( path.basename.to_s, **opts ) do |fh|
			yield( fh )

			newfile = Pathname( fh.path ).expand_path
			newfile.rename( path )

			path.chown( owner, group )
			path.chmod( mode )
		end
	end


	### Output debugging information about documentation.
	def output_documentation_debugging
		summary = self.extract_summary
		description = self.extract_description
		homepage = self.extract_homepage || DEFAULT_HOMEPAGE

		self.prompt.say( "Documentation", color: :bright_green )
		self.prompt.say( "Authors:" )
		self.authors.each do |author|
			self.prompt.say( " • " )
			self.prompt.say( author, color: :bold )
		end
		self.prompt.say( "Summary: " )
		self.prompt.say( summary, color: :bold )
		self.prompt.say( "Description:" )
		self.prompt.say( "   " + description, color: :bold )
		self.prompt.say( "Homepage:" )
		self.prompt.say( "   " + homepage, color: :bold )
		self.prompt.say( "\n" )
	end


	### Output debugging info related to the list of project files the build
	### operates on.
	def output_project_files_debugging
		self.prompt.say( "Project files:", color: :bright_green )
		table = self.generate_project_files_table
		if table.empty?
			self.prompt.warn( "None." )
		else
			self.prompt.say( table.render(:unicode, padding: [0,1]) )
		end
		self.prompt.say( "\n" )

		self.prompt.say( "Version from:" )
		self.prompt.say( "  " + self.version_from.to_s, color: :bold )
		self.prompt.say( "\n" )
	end


	### Output debugging about the project's dependencies.
	def output_dependency_debugging
		self.prompt.say( "Dependencies", color: :bright_green )
		table = self.generate_dependencies_table
		if table.empty?
			self.prompt.warn( "None." )
		else
			self.prompt.say( table.render(:unicode, padding: [0,1]) )
		end
		self.prompt.say( "\n" )
	end


	### Return a copy of the given text prefixed by +spaces+ number of spaces.
	def indent( text, spaces=4 )
		prefix = ' ' * spaces
		return text.gsub( /(?<=\A|\n)/m, prefix )
	end


	#######
	private
	#######

	### Ensure the given +gemname+ is valid, raising if it isn't.
	def validate_gemname( gemname )
		raise ScriptError, "invalid gem name" unless
			Gem::SpecificationPolicy::VALID_NAME_PATTERN.match?( gemname )
		return gemname.freeze
	end


	### Log a reason that extraction of the specified +item+ failed for the given
	### +reason+ and then return +nil+.
	def fail_extraction( item, reason )
		self.prompt.warn "Extraction of %s failed: %s" % [ item, reason ]
		return nil
	end


	### Convenience mapping -- fetch a value for the setting of the given +name+
	### from the appropriate environment variable. Returns +nil+ if that variable is
	### undefined or blank.
	def env( name, as_pathname: false )
		env_name = ENV_SETTING_NAME[ name ] or return nil
		val = ENV[ env_name ] or return nil
		return val unless as_pathname
		return PROJECT_DIR + val
	end


	### Return the path to the file that should contain the VERSION constant.
	def version_file_from( name )
		return name.
			split( /-/ ).
			reject {|word| PACKAGE_IGNORE_WORDS.include?(word) }.
			join( '/' )
	end


	### Delete the files in the given +filelist+ after confirming with the user.
	def delete_extra_files( *filelist )
		description = humanize_file_list( filelist, '	 ' )
		self.prompt.say "Files to delete:"
		self.prompt.say( description )

		if self.prompt.yes?( "Really delete them?" ) {|q| q.default(false) }
			filelist.each do |f|
				rm_rf( f, verbose: true )
			end
		end
	end


	### Returns a human-scannable file list by joining and truncating the list if it's too long.
	def humanize_file_list( list, indent=FILE_INDENT )
		listtext = list[0..5].join( "\n#{indent}" )
		if list.length > 5
			listtext << " (and %d other/s)" % [ list.length - 5 ]
		end

		return listtext
	end

end # class Rake::DevEiate
