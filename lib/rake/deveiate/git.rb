# -*- ruby -*-
# frozen_string_literal: true

require 'tempfile'
require 'shellwords'
require 'git'
require 'tty/editor'

require 'rake/deveiate' unless defined?( Rake::DevEiate )
require 'rake/deveiate/git-refinements'

using Rake::DevEiate::GitRefinements


# Git version-control tasks
module Rake::DevEiate::Git

	# The name of the file to edit for the commit message
	COMMIT_MSG_FILE = Pathname( 'commit-msg.txt' )

	# The name of the ignore file
	IGNORE_FILE = Rake::DevEiate::PROJECT_DIR + '.gitignore'

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


	### Define version-control tasks
	def define_tasks
		super if defined?( super )

		return unless self.is_git_working_copy?

		# :TODO: Should be refactored up with the same code in the hg lib.
		file COMMIT_MSG_FILE.to_s do |task|
			commit_log = Pathname( task.name )

			edit_git_commit_log( commit_log )
			unless commit_log.size?
				self.prompt.error "Empty commit message; aborting."
				commit_log.unlink if commit_log.exist?
				abort
			end
		end

		CLEAN.include( COMMIT_MSG_FILE.to_s )

		namespace :git do

			desc "Prepare for a new release"
			task( :prerelease, &method(:do_git_prerelease) )

			desc "Check for new files and offer to add/ignore/delete them."
			task( :newfiles, &method(:do_git_newfiles) )
			task :add => :newfiles

			desc "Pull and update from the default repo"
			task( :pull, &method(:do_git_pull) )

			desc "Pull and update without confirmation"
			task( :pull_without_confirmation, &method(:do_git_pull_without_confirmation) )

			desc "Update to tip"
			task( :update, &method(:do_git_update) )

			desc "Clobber all changes (git up -C)"
			task( :update_and_clobber, &method(:do_git_update_and_clobber) )

			desc "Git-specific pre-checkin hook"
			task :precheckin => [ :pull, :newfiles, :check_for_changes ]

			desc "Check the current code in if tests pass"
			task( :checkin => COMMIT_MSG_FILE.to_s, &method(:do_git_checkin) )

			desc "Git-specific pre-release hook"
			task :prerelease => 'git:check_history'

			desc "Git-specific post-release hook"
			task( :postrelease, &method(:do_git_postrelease) )

			desc "Push to the default origin repo (if there is one)"
			task( :push, &method(:do_git_push) )

			desc "Push to the default repo without confirmation"
			task :push_without_confirmation do |task, args|
				self.git.push
			end

			desc "Check the history file to ensure it contains an entry for each release tag"
			task( :check_history, &method(:do_git_check_history) )

			desc "Generate and edit a new version entry in the history file"
			task( :update_history, &method(:do_git_update_history) )

			task( :check_for_changes, &method(:do_git_check_for_changes) )
			task( :debug, &method(:do_git_debug) )
		end


		# Hook some generic tasks to the mercurial-specific ones
		task :checkin => 'git:checkin'
		task :precheckin => 'git:precheckin'

		task :prerelease => 'git:prerelease'
		task :postrelease => 'git:postrelease'

		desc "Update the history file with the changes since the last version tag."
		task :update_history => 'git:update_history'

		task :debug => 'git:debug'
	rescue ::Exception => err
		$stderr.puts "%s while defining Git tasks: %s" % [ err.class.name, err.message ]
		raise
	end


	### Returns +true+ if the current directory looks like a Git working copy.
	def is_git_working_copy?
		return File.directory?( '.git' )
	end


	### The body of the git:prerelease task.
	def do_git_prerelease( task, args )
		uncommitted_files = self.git.status( n: true )
		unless uncommitted_files.empty?
			self.show_git_file_statuses( uncommitted_files )

			fail unless self.prompt.yes?( "Release anyway?" ) do |q|
				q.default( false )
			end

			self.prompt.warn "Okay, releasing with uncommitted versions."
		end

		pkg_version_tag = self.current_git_version_tag
		rev = self.git.identity.id

		# Look for a tag for the current release version, and if it exists abort
		if self.git.tags.find {|tag| tag.name == pkg_version_tag }
			self.prompt.error "Version #{self.version} already has a tag."
			fail
		end

		# Tag the current rev
		self.prompt.ok "Tagging rev %s as %s" % [ rev, pkg_version_tag ]
		self.git.tag( pkg_version_tag, rev: rev )

		# Sign the tag
		if self.git.extension_enabled?( :gpg )
			if self.prompt.yes?( "Sign %s?" % [pkg_version_tag] )
				self.git.sign( pkg_version_tag, message: "Signing %s" % [pkg_version_tag] )
			end
		end
	end


	### The body of the git:postrelease task.
	def do_git_postrelease( task, args )
		if self.git.status( 'checksum', unknown: true ).any?
			self.prompt.say "Adding release artifacts..."
			self.git.add( 'checksum' )
			self.git.commit( 'checksum', message: "Adding release checksum." )
		end

		if self.prompt.yes?( "Move released changesets to public phase?" )
			self.prompt.say "Publicising changesets..."
			self.git.phase( public: true )
		end

		if self.git.extension_enabled?( :topic )
			current_topic = self.git.topic
			if current_topic && self.prompt.yes?( "Clear the current topic (%s)?" %[current_topic] )
				self.git.topic( clear: true )
			end
		end

		Rake::Task['git:push'].invoke
	end


	### The body of the git:newfiles task.
	def do_git_newfiles( task, args )
		self.prompt.say "Checking for new files..."
		status = self.git.status

		files_to_add = status.changed.keys
		files_to_ignore = []
		files_to_delete = []

		status.untracked.each do |path, status_file|
			description = "  %s: untracked" % [ path ]
			action = self.prompt.select( description ) do |menu|
				menu.choice "add", :a
				menu.choice "ignore", :i
				menu.choice "skip", :s
				menu.choice "delete", :d
			end

			case action
			when :a
				files_to_add << path
			when :i
				files_to_ignore << path
			when :d
				files_to_delete << path
			end
		end

		unless files_to_add.empty?
			$stderr.puts "Adding: %p" % [ files_to_add ]
			self.git.add( files_to_add )
		end

		unless files_to_ignore.empty?
			git_ignore_files( *files_to_ignore )
		end

		unless files_to_delete.empty?
			delete_extra_files( *files_to_delete )
		end
	end


	### The body of the git:pull task.
	def do_git_pull( task, args )
		origin = self.git.remote

		if ( origin_url = origin.url )
			if self.prompt.yes?( "Pull and update from '#{origin_url}'?" )
				self.prompt.say "Fetching..."
				self.git.fetch( 'origin', prune: true )
				self.prompt.say "Pulling..."
				self.git.pull( 'origin', self.git.current_branch )
			end
		else
			trace "Skipping pull: No 'origin' remote."
		end
	end


	### The body of the git:pull_without_confirmation task.
	def do_git_pull_without_confirmation( task, args )
		self.git.pull
	end


	### The body of the git:update task.
	def do_git_update( task, args )
		self.git.pull_update
	end


	### The body of the git:update_and_clobber task.
	def do_git_update_and_clobber( task, args )
		self.git.update( clean: true )
	end


	### The body of the checkin task.
	def do_git_checkin( task, args )
		commit_msg = COMMIT_MSG_FILE.read.strip

		self.prompt.say( "---", color: :cyan )
		self.prompt.say( commit_msg )
		self.prompt.say( "---", color: :cyan )

		if self.prompt.yes?( "Continue with checkin?" )
			self.git.commit( COMMIT_MSG_FILE.read )
			rm_f COMMIT_MSG_FILE
		else
			abort
		end
		Rake::Task[ 'git:push' ].invoke
	end


	### The body of the push task.
	def do_git_push( task, args )
		git = self.git
		origin = git.remote

		if (origin_url = origin.url)
			if self.prompt.yes?( "Push to '#{origin_url}'?" ) {|q| q.default(false) }
				unless git.is_remote_branch?( git.current_branch )
					if self.prompt.yes?( "Create tracking branch?" ) {|q| q.default(true) }
						tracking_branch = "origin/%s" % [ git.current_branch ]
						git.cmd( 'branch', ['-u', tracking_branch] )
					end
				end

				git.push( 'origin', git.current_branch )
				self.prompt.ok "Done."
			else
				abort
			end
		else
			trace "Skipping push: No 'default' path."
		end
	end


	### Check the history file against the list of release tags in the working copy
	### and ensure there's an entry for each tag.
	def do_git_check_history( task, args )
		unless self.history_file.readable?
			self.prompt.error "History file is missing or unreadable."
			abort
		end

		self.prompt.say "Checking history..."
		missing_tags = self.get_git_unhistoried_version_tags

		unless missing_tags.empty?
			self.prompt.error "%s needs updating; missing entries for tags: %s" %
				[ self.history_file, missing_tags.join(', ') ]
			abort
		end
	end


	### Check the status of the repo and ensure there are outstanding changes. If there
	### are no changes, abort.
	def do_git_check_for_changes( task, args )
		# :FIXME: Figure out a better way to do this.
		unless self.git.status.any?( &:type )
			self.prompt.error "Working copy is clean."
			abort
		end
	end


	### Generate a new history file entry for the current version.
	def do_git_update_history( task, args ) # Needs refactoring
		unless self.history_file.readable?
			self.prompt.error "History file is missing or unreadable."
			abort
		end

		version_tag = self.current_git_version_tag
		previous_tag = self.previous_git_version_tag
		self.prompt.say "Updating history for %s..." % [ version_tag ]

		if self.get_history_file_versions.include?( version_tag )
			self.trace "History file already includes a section for %s" % [ version_tag ]
			abort
		end

		header, rest = self.history_file.read( encoding: 'utf-8' ).
			split( /(?<=^---)/m, 2 )

		self.trace "Rest is: %p" % [ rest ]
		if !rest || rest.empty?
			self.prompt.warn "History file needs a header with a `---` marker to support updating."
			self.prompt.say "Adding an auto-generated one."
			rest = header
			header = self.load_and_render_template( 'History.erb', self.history_file )
		end

		header_char = self.header_char_for( self.history_file )
		ext = self.history_file.extname
		log_entries = if previous_tag
				self.git.log( rev: "#{previous_tag}~-2::" )
			else
				self.git.log
			end

		Tempfile.create( ['History', ext], encoding: 'utf-8' ) do |tmp_copy|
			tmp_copy.print( header )
			tmp_copy.puts

			tmp_copy.puts "%s %s [%s] %s" % [
				header_char * 2,
				version_tag,
				Date.today.strftime( '%Y-%m-%d' ),
				self.authors.first,
			]

			tmp_copy.puts
			log_entries.each do |entry|
				tmp_copy.puts "- %s" % [ entry.message ]
			end
			tmp_copy.puts
			tmp_copy.puts

			tmp_copy.print( rest )
			tmp_copy.close

			TTY::Editor.open( tmp_copy.path )

			if File.size?( tmp_copy.path )
				cp( tmp_copy.path, self.history_file )
			else
				self.prompt.error "Empty file: aborting."
			end
		end

	end


	### Show debugging information.
	def do_git_debug( task, args )
		self.prompt.say( "Git Info", color: :bright_green )

		if self.is_git_working_copy?
			self.prompt.say( "Release tag prefix: " )
			self.prompt.say( self.release_tag_prefix, color: :bold )

			self.prompt.say( "Version tags:" )
			self.get_git_version_tag_names.each do |tag|
				self.prompt.say( '- ' )
				self.prompt.say( tag, color: :bold )
			end

			self.prompt.say( "History file versions:" )
			self.get_history_file_versions.each do |tag|
				self.prompt.say( '- ' )
				self.prompt.say( tag, color: :bold )
			end

			self.prompt.say( "Unhistoried version tags:" )
			self.get_git_unhistoried_version_tags.each do |tag|
				self.prompt.say( '- ' )
				self.prompt.say( tag, color: :bold )
			end
		else
			self.prompt.say( "Doesn't appear to be a Git repository." )
		end

		self.prompt.say( "\n" )
	end

	#
	# utility methods
	#

	### Return a Git::Repo for the directory rake was invoked in, creating it if
	### necessary.
	def git
		@git ||= Git.open( Rake::DevEiate::PROJECT_DIR )
	end


	### Given a +status_hash+ like that returned by Git::Repo.status, return a
	### string description of the files and their status.
	def show_git_file_statuses( statuses )
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


	### Fetch the name of the current version's tag.
	def current_git_version_tag
		return [ self.release_tag_prefix, self.version ].join
	end


	### Fetch the name of the tag for the previous version.
	def previous_git_version_tag
		return self.get_git_version_tag_names.first
	end


	### Fetch the list of names of tags that match the versioning scheme of this
	### project.
	def get_git_version_tag_names
		tag_pattern = /#{self.release_tag_pattern}$/
		return self.git.tags.map( &:name ).grep( tag_pattern )
	end


	### Read the list of tags and return any that don't have a corresponding section
	### in the history file.
	def get_git_unhistoried_version_tags( include_current_version: true )
		release_tags = self.get_git_version_tag_names
		release_tags.unshift( self.current_git_version_tag ) if include_current_version

		self.get_history_file_versions.each do |tag|
			release_tags.delete( tag )
		end

		return release_tags
	end


	### Generate a commit log and invoke the user's editor on it.
	def edit_git_commit_log( logfile )
		diff = self.git.diff

		TTY::Editor.open( logfile, text: diff )
	end


	### Add the list of +pathnames+ to the .gitignore list.
	def git_ignore_files( *pathnames )
		self.trace "Ignoring %d files." % [ pathnames.length ]

		IGNORE_FILE.open( File::CREAT|File::WRONLY|File::APPEND, 0644 ) do |fh|
			fh.puts( pathnames )
		end
	end

end # module Rake::DevEiate::Git


