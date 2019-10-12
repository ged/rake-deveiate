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
			task :test => :spec

			desc "Run unit tests"
			RSpec::Core::RakeTask.new( :spec ) do |t|
				t.rspec_opts = "-cfd"
			end
		end

		if Rake::DevEiate::INT_SPEC_DIR.exist?
			task :test => :integration

			desc "Run integration tests"
			RSpec::Core::RakeTask.new( :integration ) do |t|
				t.rspec_opts = "-cfd"
				t.pattern = Rake::DevEiate::INT_SPEC_DIR + '**{,/*/**}/*_spec.rb'
			end
		end

		desc "Run specs with coverage reporting enabled"
		task :coverage do
			ENV['COVERAGE'] = 'yes'
			Rake::Task[:spec].invoke
		end


	end

end # module Rake::DevEiate::Specs


