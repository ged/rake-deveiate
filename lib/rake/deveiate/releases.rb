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

		task( :release_gem => :add_release_checksum, &method(:do_release_gem) )

		task :debug => :release_debug
		task( :release_debug, &method(:do_release_debug) )
	end


	### Create a checksum for a release gemfile
	def do_make_release_checksum( task, args )
		if self.prompt.yes?( "Make a checksum for this release?" )
			checksum = Digest::SHA512.new.hexdigest( self.gem_path.read )
			File.open( task.name, 'w', encoding: 'us-ascii' ) {|f| f.write(checksum) }
		end
	end


	### Body of the release_gem task.
	def do_release_gem( task, args )
		gemserver = self.allowed_push_host || Rake::DevEiate::DEFAULT_GEMSERVER

		case gemserver
		when /\Ascp:/
			self.do_scp_push( gemserver )
		else
			self.do_gem_push( gemserver )
		end
	end


	### Push a new gem via a gemserver.
	def do_gem_push( gemserver )
		if self.prompt.yes?( "Push a new gem to #{gemserver}?" ) {|q| q.default(false) }
			push_args = [ "push", self.gem_path.to_s ]
			push_args << '-k' << self.gem_push_key if self.gem_push_key

			sh( Gem.ruby, "-S", "gem", *push_args )
		end
	end


	### Push a new gem via scp.
	def do_scp_push( gemserver )
		gemserver_url = URI( gemserver )

		if self.prompt.yes?( "Push a new gem with scp to #{gemserver_url.host}?" ) {|q| q.default(false) }
			require 'net/scp'

			# Strip off one leading '/' if one is present
			remote_path = gemserver_url.path[ %r{/(.*)}, 1 ]

			Net::SCP.upload!( gemserver_url.host, gemserver_url.user, self.gem_path.to_s, remote_path )
		end
	end


	### Body of the release_debug task.
	def do_release_debug( task, args )
		gemserver = self.allowed_push_host || Rake::DevEiate::DEFAULT_GEMSERVER

		self.prompt.say( "Releases will be pushed to:", color: :bright_green )
		self.prompt.say( self.indent(gemserver, 4) )
		self.prompt.say( "\n" )
	end

end # module Rake::DevEiate::Releases

