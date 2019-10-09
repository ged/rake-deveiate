# -*- ruby -*-
# frozen_string_literal: true

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Packaging tasks and functions
module Rake::DevEiate::Packaging


	### Post-loading hook -- set up default attributes.
	def setup( name, **options )
		super if defined?( super )

		gem_basename = "%s-%s" % [ name, self.version ]

		@gem_filename = gem_basename + '.gem'
		@gem_dir      = Rake::DevEiate::PKG_DIR + gem_basename
		@gem_path     = Rake::DevEiate::PKG_DIR + @gem_filename
	end


	### Define packaging tasks.
	def define_tasks
		super if defined?( super )
		spec = self.gemspec

		task :package => [ :gem ]

		directory( Rake::DevEiate::PKG_DIR )
		directory( self.gem_dir )

		desc "Build the gem file #{gem_file}"
		task :gem => [ self.gem_path ]

		trace = Rake.application.options.trace
		Gem.configuration.verbose = trace

		package_dir = Rake::DevEiate::PKG_DIR

		file self.gem_path => [ package_dir, self.gem_dir ] + spec.files do
			chdir( self.gem_dir ) do
				when_writing "Creating #{self.gem_filename}" do
					Gem::Package.build( spec )

					verbose( trace ) do
						mv gem_file, '..'
					end
				end
			end
		end
	end


	##
	# The filename of the generated gemfile
	attr_reader :gem_filename

	##
	# The Pathname of the directory that will be used to stage the gem
	attr_reader :gem_dir

	##
	# The Pathname of the generated gemfile
	attr_reader :gem_path


end # module Rake::DevEiate::Packaging

