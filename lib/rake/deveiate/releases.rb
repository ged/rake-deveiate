# -*- ruby -*-
# frozen_string_literal: true

require 'digest/sha2'
require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Release tasks
module Rake::DevEiate::Releases


	### Define release tasks.
	def define_tasks
		super if defined?( super )

		checksum_dir = Rake::DevEiate::CHECKSUM_DIR
		checksum_path = checksum_dir + "#{self.gem_filename}.sha512"

		directory( checksum_dir )

		file( checksum_path => [self.gem_path, checksum_dir], &method(:do_make_release_checksum) )
		task :add_release_checksum => checksum_path

		task :release_gem => :add_release_checksum do
			sh( Gem.ruby, "-S", "gem", "push", self.gem_path.to_s )
		end

	end


	### Create a checksum for a release gemfile
	def do_make_release_checksum( task, args )
		if self.prompt.yes?( "Make a checksum for this release?" )
			checksum = Digest::SHA512.new.hexdigest( self.gem_path.read )
			File.open( task.name, 'w', encoding: 'us-ascii' ) {|f| f.write(checksum) }
		end
	end

end # module Rake::DevEiate::Releases

