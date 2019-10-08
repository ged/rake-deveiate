# -*- ruby -*-
# frozen_string_literal: true

require 'rubygems/package_task'

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Packaging tasks and functions
module Rake::DevEiate::Packaging


	### Define release tasks.
	def define_tasks
		super if defined?( super )

		spec = self.make_gemspec
		Gem::PackageTask.new( spec ).define

	end



end # module Rake::DevEiate::Packaging

