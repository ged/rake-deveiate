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

class Rake::DevEiate < Rake::TaskLib
	include Rake::TraceOutput


	PROJECT_DIR = Pathname.pwd

	DOCS_DIR = PROJECT_DIR + 'docs'
	LIB_DIR = PROJECT_DIR + 'lib'
	EXT_DIR = PROJECT_DIR + 'ext'
	SPEC_DIR = PROJECT_DIR + 'spec'


	README_FILES = Rake::FileList[ PROJECT_DIR + 'README.{md,rdoc}' ]
	RDOC_FILES = Rake::FileList[ "*.rdoc", "*.md", "lib/*.rb", "lib/**/*.rb", "ext/**/*.[ch]" ]


	### Set up common development tasks
	def self::setup( gemname, **options )
		return self.new( gemname, **options )
	end



	### Create the devEiate tasks for a gem with the given +gemname+.
	def initialize( gemname, **options, &block )
		@gemname = validate_gemname( gemname )
		@options = options

		@title = gemname.to_s.capitalize

		self.instance_exec( self, &block ) if block

		self.define_default_task
		self.load_task_libraries
	end


	######
	public
	######

	##
	# The name of the gem the task will build
	attr_reader :gemname

	##
	# The title of the library for things like docs, gemspec, etc.
	attr_accessor :title


	### Set up a simple default task
	def define_default_task
		desc "The task that runs by default"
		task( :default => :spec )
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
