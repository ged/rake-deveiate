# -*- ruby -*-
# frozen_string_literal: true

require 'rspec/core/rake_task'
require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Testinug specification tasks
module Rake::DevEiate::Specs

	### Define documentation tasks
	def self::define_tasks( tasklib )

		RSpec::Core::RakeTask.new( :spec ) do |t|
			t.rspec_opts = "-cfd"
		end

	end

end # module Rake::DevEiate::Specs


