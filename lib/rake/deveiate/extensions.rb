# -*- ruby -*-
# frozen_string_literal: true

require 'pathname'
require 'rake'

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Extension compilation and maintenance tasks
module Rake::DevEiate::Extension
	extend Rake::DSL

	# The glob pattern to use when looking for extension config scripts (relative to
	# EXT_DIR).
	EXTENSION_GLOB_PATTERN = '**/extconf.rb'


	### Set some defaults when the task lib is set up.
	def setup( _name, **options )
		super if defined?( super )

		self.extensions.include( Rake::DevEiate::EXT_DIR + EXTENSION_GLOB_PATTERN )
		@disable_rake_compiler = false
	end


	##
	# Set to +true+ to indicate that this project provides its own
	# extension-management tasks.
	attr_accessor :disable_rake_compiler


	### Predicate for the #disable_rake_compiler attribute.
	def disable_rake_compiler?
		return self.disable_rake_compiler ? true :false
	end


	### Returns +true+ if there appear to be extensions as part of the current
	### project.
	def extensions_present?
		return !self.extensions.empty?
	end


	### Define extension tasks
	def define_tasks
		super if defined?( super )

		if self.extensions_present?
			if self.has_rakecompiler_dependency?
				self.define_extension_tasks
			elsif !self.disable_rake_compiler?
				warn <<~END_WARNING

					You appear to have one or more extensions, but rake-compiler
					is not a dependency. You should either add it to gem.deps.rb
					or set `disable_rake_compiler` on the project to disable this
					warning.

				END_WARNING
			end
		end

		task( :extensions_debug, &method(:do_extensions_debug) )
		task :debug => :extensions_debug
	end


	### Set up the tasks to build extensions.
	def define_extension_tasks
		ENV['RUBY_CC_VERSION'] ||= RUBY_VERSION[ /(\d+\.\d+)/ ]

		require 'rake/extensiontask'
		self.extensions.each do |extconf|
			Rake::ExtensionTask.new( extconf.pathmap('%-1d') )
		end

		task :spec => :compile
	end


	### Returns +true+ if the projects dependencies include `rake-compiler`.
	def has_rakecompiler_dependency?
		return self.dependencies.any? do |dep|
			dep.name == 'rake-compiler'
		end
	end



	### Task function -- output debugging for extension tasks.
	def do_extensions_debug( task, args )
		self.prompt.say( "Extension config scripts:", color: :bright_green )

		if self.extensions.empty?
			self.prompt.say( "None." )
		else
			self.extensions.each do |path|
				self.prompt.say "- %s" % [ path ]
			end
		end

		if self.has_rakecompiler_dependency?
		end

		self.prompt.say( "\n" )
	end


end # module Rake::DevEiate::Extensions


