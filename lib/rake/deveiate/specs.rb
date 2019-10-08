# -*- ruby -*-
# frozen_string_literal: true

require 'rspec/core/rake_task'
require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Testinug specification tasks
module Rake::DevEiate::Specs

	### Define documentation tasks
	def define_tasks
		super if defined?( super )

		if Rake::DevEiate::SPEC_DIR.exist?
			RSpec::Core::RakeTask.new( :spec ) do |t|
				t.rspec_opts = "-cfd"
			end
		end

	end

end # module Rake::DevEiate::Specs


