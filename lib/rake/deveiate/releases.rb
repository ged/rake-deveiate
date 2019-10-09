# -*- ruby -*-
# frozen_string_literal: true

require 'digest/sha2'
require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Release tasks
module Rake::DevEiate::Releases


	### Define release tasks.
	def define_tasks
		task :release

		super if defined?( super )
	end



	### (Undocumented)
	def method_name
		gem_path = self.gem_path
		checksum = Digest::SHA512.new.hexdigest(  )
		checksum_path = 'checksum/gemname-version.gem.sha512'
		File.open(checksum_path, 'w' ) {|f| f.write(checksum) }
		# add and commit 'checksum_path'
	end

end # module Rake::DevEiate::Releases

