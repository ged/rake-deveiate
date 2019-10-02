# -*- ruby -*-
# frozen_string_literal: true

require 'shellwords'
require 'hglib'
require 'tty/editor'

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Version-control tasks
module Rake::DevEiate::Hg

	# The name of the file to edit for the commit message
	COMMIT_MSG_FILE = Pathname( 'commit-msg.txt' )

	# The name of the ignore file
	IGNORE_FILE = Rake::DevEiate::PROJECT_DIR + '.hgignore'

	# The prefix to use for release version tags by default
	DEFAULT_RELEASE_TAG_PREFIX = 'v'

	# Colors for presenting file statuses
	STATUS_COLORS = {
		'M' => [:blue],                  # modified
		'A' => [:bold, :green],          # added
		'R' => [:bold, :black],          # removed
		'C' => [:white],                 # clean
		'!' => [:bold, :white, :on_red], # missing
		'?' => [:yellow],                # not tracked
		'I' => [:dim, :white],           # ignored
	}

	# File indentation
	FILE_INDENT = " • "


	### Set up defaults
	def initialize( _name, **options )
		super if defined?( super )

		@release_tag_prefix       = options[:release_tag_prefix] || DEFAULT_RELEASE_TAG_PREFIX
		@sign_tags                = options[:sign_tags] || true
		@check_history_on_release = options[:check_history_on_release] || true
	end


	##
	# The prefix to use for version tags
	attr_accessor :release_tag_prefix

	##
	# Boolean: if true, sign tags after creating them
	attr_accessor :sign_tags

	##
	# Boolean: check the history file to be sure it includes the current version
	# when packaging up a release
	attr_accessor :check_history_on_release


	### Define version-control tasks
	def define_tasks
		super if defined?( super )

		file COMMIT_MSG_FILE.to_s do |task|
			edit_commit_log( task.name )
		end

		CLEAN.include( COMMIT_MSG_FILE.to_s )

		namespace :hg do

			desc "Prepare for a new release"
			task( :prep_release, &method(:do_prep_release) )

			desc "Check for new files and offer to add/ignore/delete them."
			task( :newfiles, &method(:do_newfiles) )
			task :add => :newfiles

			desc "Pull and update from the default repo"
			task( :pull, &method(:do_pull) )

			desc "Pull and update without confirmation"
			task( :pull_without_confirmation, &method(:do_pull_without_confirmation) )

			desc "Update to tip"
			task( :update, &method(:do_update) )

			desc "Clobber all changes (hg up -C)"
			task( :update_and_clobber, &method(:do_update_and_clobber) )

			task :precheckin do
				trace "Pre-checkin hooks"
			end

			desc "Check the current code in if tests pass"
			task( :checkin => [:pull, :newfiles, :precheckin, COMMIT_MSG_FILE.to_s], &method(:do_checkin) )
			task :commit => :checkin
			task :ci => :checkin

			desc "Push to the default origin repo (if there is one)"
			task( :push, &method(:do_push) )

			desc "Push to the default repo without confirmation"
			task :push_without_confirmation do |task, args|
				self.hg.push
			end

		end


		# Add a top-level 'ci' task for checkin
		desc "Check in your changes"
		task :ci => 'hg:checkin'

		# Hook the release task and prep the repo first
		task :prerelease => 'hg:prep_release'

		desc "Check the history file to ensure it contains an entry for each release tag"
		task :check_history do
			self.prompt.say "Checking history..."
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


	### Given a +status_hash+ like that returned by Hglib::Repo.status, return a
	### string description of the files and their status.
	def show_file_statuses( statuses )
		lines = statuses.map do |entry|
			status_color = STATUS_COLORS[ entry.status ]
			"	%s: %s" % [
				self.pastel.white( entry.path.to_s ),
				self.pastel.decorate( entry.status_description, *status_color ),
			]
		end

		self.prompt.say( self.pastel.headline "Uncommitted files:" )
		self.prompt.say( lines.join("\n") )
	end


	### The body of the hg:prep_release task.
	def do_prep_release( task, args )
		uncommitted_files = self.hg.status( n: true )
		unless uncommitted_files.empty?
			self.show_file_statuses( uncommitted_files )

			fail unless self.prompt.yes?( "Release anyway?" ) do |q|
				q.default( false )
			end

			self.prompt.warn "Okay, releasing with uncommitted versions."
		end

		rev = self.hg.identify
		pkg_version_tag = [ self.release_tag_prefix, self.version ].join

		# Look for a tag for the current release version, and if it exists abort
		if self.hg.tags.find {|tag| tag.name == pkg_version_tag }
			error "Version #{self.version} already has a tag."
			fail
		end

		# Ensure that the History file contains an entry for every release
		Rake::Task[ 'check_history' ].invoke if self.check_history_on_release

		# Sign the current rev
		if self.sign_tags
			self.prompt.say "Signing rev #{rev}"
			run 'hg', 'sign'
		end

		# Tag the current rev
		self.prompt.say "Tagging rev #{rev} as #{pkg_version_tag}"
		run 'hg', 'tag', pkg_version_tag

		# Offer to push
		Rake::Task['hg:push'].invoke
	end


	### The body of the hg:newfiles task.
	def do_newfiles( task, args )
		self.prompt.say "Checking for new files..."

		entries = self.hg.status( no_status: true, unknown: true )

		unless entries.empty?
			files_to_add = []
			files_to_ignore = []
			files_to_delete = []

			entries.each do |entry|
				description = "  %s: %s" % [ entry.path, entry.status_description ]
				action = self.prompt.select( description ) do |menu|
					menu.choice "add", :a
					menu.choice "ignore", :i
					menu.choice "skip", :s
					menu.choice "delete", :d
				end

				case action
				when :a
					files_to_add << entry.path
				when :i
					files_to_ignore << entry.path
				when :d
					files_to_delete << entry.path
				end
			end

			unless files_to_add.empty?
				self.hg.add( *files_to_add )
			end

			unless files_to_ignore.empty?
				hg_ignore_files( *files_to_ignore )
			end

			unless files_to_delete.empty?
				delete_extra_files( *files_to_delete )
			end
		end
	end


	### The body of the hg:pull task.
	def do_pull( task, args )
		paths = self.hg.paths
		if origin_url = paths[:default]
			if self.prompt.yes?( "Pull and update from '#{origin_url}'?" )
				self.hg.pull_update
			end
		else
			trace "Skipping pull: No 'default' path."
		end
	end


	### The body of the hg:pull_without_confirmation task.
	def do_pull_without_confirmation( task, args )
		run 'hg', 'pull', '-u'
	end


	### The body of the hg:update task.
	def do_update( task, args )
		run 'hg', 'update'
	end


	### The body of the hg:update_and_clobber task.
	def do_update_and_clobber( task, args )
		run 'hg', 'update', '-C'
	end


	### The body of the checkin task.
	def do_checkin( task, args )
		targets = args.extras
		self.prompt.say( self.pastel.cyan( "---\n", COMMIT_MSG_FILE.read, "---\n" ) )
		if self.prompt.yes?( "Continue with checkin?" )
			self.hg.commit( *targets, logfile: COMMIT_MSG_FILE.to_s )
			rm_f COMMIT_MSG_FILE
		end
		Rake::Task[ 'hg:push' ].invoke
	end


	### The body of the push task.
	def do_push( task, args )
		paths = self.hg.paths
		if origin_url = paths[:default]
			if self.prompt.yes?( "Push to '#{origin_url}'?" ) {|q| q.default(false) }
				self.hg.push
			end
		else
			trace "Skipping push: No 'default' path."
		end
	end


	#
	# utility methods
	#

	### Return an Hglib::Repo for the directory rake was invoked in, creating it if
	### necessary.
	def hg
		@hg ||= Hglib.repo( Rake::DevEiate::PROJECT_DIR )
	end


	### Read the list of tags and return any that don't have a corresponding section
	### in the history file.
	def get_unhistoried_version_tags( include_pkg_version=true )
		prefix = self.release_tag_prefix
		tag_pattern = /#{prefix}\d+(\.\d+)+/
		release_tags = self.hg.tags.grep( /^#{tag_pattern}$/ )

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


	### Generate a commit log and invoke the user's editor on it.
	def edit_commit_log( logfile )
		diff = self.hg.diff

		File.open( logfile, 'w' ) do |fh|
			fh.print( diff )
		end

		TTY::Editor.open( logfile )
	end


	### Add the list of +pathnames+ to the .hgignore list.
	def hg_ignore_files( *pathnames )
		patterns = pathnames.flatten.collect do |path|
			'^' + Regexp.escape(path) + '$'
		end
		self.trace "Ignoring %d files." % [ pathnames.length ]

		IGNORE_FILE.open( File::CREAT|File::WRONLY|File::APPEND, 0644 ) do |fh|
			fh.puts( patterns )
		end
	end


	### Delete the files in the given +filelist+ after confirming with the user.
	def delete_extra_files( *filelist )
		description = humanize_file_list( filelist, '	 ' )
		self.prompt.say "Files to delete:"
		self.prompt.say( description )

		if self.prompt.yes?( "Really delete them?" ) {|q| q.default(false) }
			filelist.each do |f|
				rm_rf( f, verbose: true )
			end
		end
	end


	### Returns a human-scannable file list by joining and truncating the list if it's too long.
	def humanize_file_list( list, indent=FILE_INDENT )
		listtext = list[0..5].join( "\n#{indent}" )
		if list.length > 5
			listtext << " (and %d other/s)" % [ list.length - 5 ]
		end

		return listtext
	end


end # module Rake::DevEiate::Hg


