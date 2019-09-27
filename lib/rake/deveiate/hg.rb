# -*- ruby -*-
# frozen_string_literal: true

require 'hglib'
require 'rake'
require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Version-control tasks
module Rake::DevEiate::Hg
	extend Rake::DSL


	# The name of the file to edit for the commit message
	COMMIT_MSG_FILE = 'commit-msg.txt'


	module MercurialHelpers
		include FileUtils
		include FileUtils::DryRun if Rake.application.options.dryrun

		# The name of the ignore file
		IGNORE_FILE = Pathname( '.hgignore' )


		### Generate a commit log from a diff and return it as a String. At the moment it just
		### returns the diff as-is, but will (someday) do something better.
		def make_commit_log
			diff = read_command_output( 'hg', 'diff' )
			fail "No differences." if diff.empty?

			return diff
		end


		### Generate a commit log and invoke the user's editor on it.
		def edit_commit_log( logfile )
			diff = make_commit_log()

			File.open( logfile, 'w' ) do |fh|
				fh.print( diff )
			end

			edit( logfile )
		end


		### Generate a changelog.
		def make_changelog
			log = read_command_output( 'hg', 'log', '--style', 'changelog' )
			return log
		end


		def get_manifest
			raw = read_command_output( 'hg', 'manifest' )
			return raw.split( $/ )
		end


		### Get the 'tip' info and return it as a Hash
		def get_tip_info
			data = read_command_output( 'hg', 'tip' )
			return YAML.load( data )
		end


		### Return the ID for the current rev
		def get_current_rev
			id = read_command_output( 'hg', '-q', 'identify' )
			return id.chomp
		end


		### Return the current numeric (local) rev number
		def get_numeric_rev
			id = read_command_output( 'hg', '-q', 'identify', '-n' )
			return id.chomp[ /^(\d+)/, 1 ] || '0'
		end


		### Read the list of existing tags and return them as an Array
		def get_tags
			taglist = read_command_output( 'hg', 'tags' )
			return taglist.split( /\n/ ).collect {|tag| tag[/^\S+/] }
		end


		### Read any remote repo paths known by the current repo and return them as a hash.
		def get_repo_paths
			paths = {}
			pathspec = read_command_output( 'hg', 'paths' )
			pathspec.split.each_slice( 3 ) do |name, _, url|
				paths[ name ] = url
			end
			return paths
		end


		### Return the list of files which are not of status 'clean'
		def get_uncommitted_files
			self.repo.
			list = read_command_output( 'hg', 'status', '-n', '--color', 'never' )
			list = list.split( /\n/ )

			trace "Changed files: %p" % [ list ]
			return list
		end


		### Return the list of files which are of status 'unknown'
		def get_unknown_files
			list = read_command_output( 'hg', 'status', '-un', '--color', 'never' )
			list = list.split( /\n/ )

			trace "New files: %p" % [ list ]
			return list
		end


		### Add the list of +pathnames+ to the .hgignore list.
		def hg_ignore_files( *pathnames )
			patterns = pathnames.flatten.collect do |path|
				'^' + Regexp.escape(path) + '$'
			end
			trace "Ignoring %d files." % [ pathnames.length ]

			IGNORE_FILE.open( File::CREAT|File::WRONLY|File::APPEND, 0644 ) do |fh|
				fh.puts( patterns )
			end
		end


		### Delete the files in the given +filelist+ after confirming with the user.
		def delete_extra_files( filelist )
			description = humanize_file_list( filelist, '	 ' )
			log "Files to delete:\n ", description
			ask_for_confirmation( "Really delete them?", false ) do
				filelist.each do |f|
					rm_rf( f, :verbose => true )
				end
			end
		end

	end # module MercurialHelpers


	###############
	module_function
	###############

	### Define version-control tasks
	def define_tasks( tasklib )

		file COMMIT_MSG_FILE do |task|
			edit_commit_log( task.name )
		end

		namespace :hg do

			desc "Prepare for a new release"
			task( :prep_release, &method(:prep_release) )


			desc "Check for new files and offer to add/ignore/delete them."
			task :newfiles do
				log "Checking for new files..."

				entries = get_unknown_files()

				unless entries.empty?
					files_to_add = []
					files_to_ignore = []
					files_to_delete = []

					entries.each do |entry|
						action = prompt_with_default( "	 #{entry}: (a)dd, (i)gnore, (s)kip (d)elete", 's' )
						case action
						when 'a'
							files_to_add << entry
						when 'i'
							files_to_ignore << entry
						when 'd'
							files_to_delete << entry
						end
					end

					unless files_to_add.empty?
						run 'hg', 'add', *files_to_add
					end

					unless files_to_ignore.empty?
						hg_ignore_files( *files_to_ignore )
					end

					unless files_to_delete.empty?
						delete_extra_files( files_to_delete )
					end
				end
			end
			task :add => :newfiles


			desc "Pull and update from the default repo"
			task :pull do
				paths = get_repo_paths()
				if origin_url = paths['default']
					ask_for_confirmation( "Pull and update from '#{origin_url}'?", false ) do
						Rake::Task['hg:pull_without_confirmation'].invoke
					end
				else
					trace "Skipping pull: No 'default' path."
				end
			end


			desc "Pull and update without confirmation"
			task :pull_without_confirmation do
				run 'hg', 'pull', '-u'
			end


			desc "Update to tip"
			task :update do
				run 'hg', 'update'
			end


			desc "Clobber all changes (hg up -C)"
			task :update_and_clobber do
				run 'hg', 'update', '-C'
			end


			task :precheckin do
				trace "Pre-checkin hooks"
			end


			desc "Check the current code in if tests pass"
			task :checkin => [:pull, :newfiles, :precheckin, COMMIT_MSG_FILE] do
				targets = get_target_args()
				$stderr.puts '---', File.read( COMMIT_MSG_FILE ), '---'
				ask_for_confirmation( "Continue with checkin?" ) do
					run 'hg', 'ci', '-l', COMMIT_MSG_FILE, targets
					rm_f COMMIT_MSG_FILE
				end
				Rake::Task['hg:push'].invoke
			end
			task :commit => :checkin
			task :ci => :checkin

			CLEAN.include( COMMIT_MSG_FILE )

			desc "Push to the default origin repo (if there is one)"
			task :push do
				paths = get_repo_paths()
				if origin_url = paths['default']
					ask_for_confirmation( "Push to '#{origin_url}'?", false ) do
						Rake::Task['hg:push_without_confirmation'].invoke
					end
				else
					trace "Skipping push: No 'default' path."
				end
			end

			desc "Push to the default repo without confirmation"
			task :push_without_confirmation do
				run 'hg', 'push'
			end
		end

		# Add a top-level 'ci' task for checkin
		desc "Check in your changes"
		task :ci => 'hg:checkin'

		# Hook the release task and prep the repo first
		task :prerelease => 'hg:prep_release'

		desc "Check the history file to ensure it contains an entry for each release tag"
		task :check_history do
			log "Checking history..."
			missing_tags = get_unhistoried_version_tags()

			unless missing_tags.empty?
				abort "%s needs updating; missing entries for tags: %p" %
					[ self.history_file, missing_tags ]
			end
		end

	rescue ::Exception => err
		$stderr.puts "%s while defining Mercurial tasks: %s" % [ err.class.name, err.message ]
		raise
	end


	### The body of the hg:prep_release task.
	def prep_release
		uncommitted_files = get_uncommitted_files()
		unless uncommitted_files.empty?
			log "Uncommitted files:\n",
				*uncommitted_files.map {|fn| "	#{fn}\n" }
			ask_for_confirmation( "\nRelease anyway?", true ) do
				log "Okay, releasing with uncommitted versions."
			end
		end

		tags = get_tags()
		rev = get_current_rev()
		pkg_version_tag = "#{hg_release_tag_prefix}#{version}"

		# Look for a tag for the current release version, and if it exists abort
		if tags.include?( pkg_version_tag )
			error "Version #{version} already has a tag."
			fail
		end

		# Ensure that the History file contains an entry for every release
		Rake::Task[ 'check_history' ].invoke if self.check_history_on_release

		# Sign the current rev
		if self.hg_sign_tags
			log "Signing rev #{rev}"
			run 'hg', 'sign'
		end

		# Tag the current rev
		log "Tagging rev #{rev} as #{pkg_version_tag}"
		run 'hg', 'tag', pkg_version_tag

		# Offer to push
		Rake::Task['hg:push'].invoke
	end


	attr_accessor :hg_release_tag_prefix
	attr_accessor :hg_sign_tags
	attr_accessor :check_history_on_release


	### Set up defaults
	def initialize_mercurial
		# Follow semantic versioning tagging specification (http://semver.org/)
		self.hg_release_tag_prefix    = "v"
		self.hg_sign_tags             = false
		self.check_history_on_release = false

		minor_version = VERSION[ /^\d+\.\d+/ ]
		self.extra_dev_deps << ['hoe-mercurial', "~> #{minor_version}"] unless
			self.name == 'hoe-mercurial'
	end


	### Read the list of tags and return any that don't have a corresponding section
	### in the history file.
	def get_unhistoried_version_tags( include_pkg_version=true )
		prefix = self.hg_release_tag_prefix
		tag_pattern = /#{prefix}\d+(\.\d+)+/
		release_tags = get_tags().grep( /^#{tag_pattern}$/ )

		release_tags.unshift( "#{prefix}#{version}" ) if include_pkg_version

		IO.readlines( self.history_file ).each do |line|
			if line =~ /^(?:h\d\.|#+|=+)\s+(#{tag_pattern})\s+/
				trace "  found an entry for tag %p: %p" % [ $1, line ]
				release_tags.delete( $1 )
			else
				trace "  no tag on line %p" % [ line ]
			end
		end

		return release_tags
	end



end # module Rake::DevEiate::Hg


