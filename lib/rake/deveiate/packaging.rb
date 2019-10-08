# -*- ruby -*-
# frozen_string_literal: true

require 'rubygems/package_task'

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Packaging tasks and functions
module Rake::DevEiate::Packaging


	### Define release tasks.
	def define_tasks
		super if defined?( super )

		pkg_dir = Rake::DevEiate::PKG_DIR
		gem_path = pkg_dir + 

		task :gem => 

		Gem::PackageTask.new spec do |pkg|
			pkg.need_tar = @need_tar
			pkg.need_zip = @need_zip
		end
	end



end # module Rake::DevEiate::Packaging

