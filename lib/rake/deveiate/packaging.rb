# -*- ruby -*-
# frozen_string_literal: true

require 'rake/clean'
require 'rubygems/package_task'

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Packaging tasks and functions
module Rake::DevEiate::Packaging

	### Post-loading hook -- set up default attributes.
	def setup( name, **options )
		super if defined?( super )

		gem_basename = "%s-%s" % [ name, self.version ]

		@gem_filename = gem_basename + '.gem'
		@gem_path     = Rake::DevEiate::PKG_DIR + @gem_filename
	end

	##
	# The filename of the generated gemfile
	attr_reader :gem_filename

	##
	# The Pathname of the generated gemfile
	attr_reader :gem_path


	### Set up packaging tasks.
	def define_tasks
		super if defined?( super )

		task :gem => :clean
		task :release_gem => :gem

		spec = self.gemspec
		Gem::PackageTask.new( spec ).define

		CLEAN.include( Rake::DevEiate::PKG_DIR.to_s )

	end

end # module Rake::DevEiate::Packaging

