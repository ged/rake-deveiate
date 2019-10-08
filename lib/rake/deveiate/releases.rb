# -*- ruby -*-
# frozen_string_literal: true

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Release tasks
module Rake::DevEiate::Releases


	### Define release tasks.
	def define_tasks
		task :release

		super if defined?( super )
	end



end # module Rake::DevEiate::Releases

