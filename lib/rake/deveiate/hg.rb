# -*- ruby -*-
# frozen_string_literal: true

require 'tempfile'
require 'shellwords'
require 'hglib'
require 'tty/editor'

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Mercurial version-control tasks
module Rake::DevEiate::Hg

	# The name of the file to edit for the commit message
	COMMIT_MSG_FILE = Pathname( 'commit-msg.txt' )

	# The name of the ignore file
	IGNORE_FILE = Rake::DevEiate::PROJECT_DIR + '.hgignore'

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

	# The name of the branch releases should be created from
	DEFAULT_RELEASE_BRANCH = 'default'


	### Define version-control tasks
	def define_tasks
		super if defined?( super )

		return unless self.is_hg_working_copy?

		# :TODO: Actually check for this? Doesn't make much as much sense given my
		# Mercurial workflow.
		self.release_branch = DEFAULT_RELEASE_BRANCH

		file COMMIT_MSG_FILE.to_s do |task|
			commit_log = Pathname( task.name )

			hg_edit_commit_log( commit_log )
			unless commit_log.size?
				self.prompt.error "Empty commit message; aborting."
				commit_log.unlink if commit_log.exist?
				abort
			end
		end

		CLEAN.include( COMMIT_MSG_FILE.to_s )

		namespace :hg do

			desc "Prepare for a new release"
			task( :prerelease, &method(:do_hg_prerelease) )

			desc "Check for new files and offer to add/ignore/delete them."
			task( :newfiles, &method(:do_hg_newfiles) )
			task :add => :newfiles

			desc "Pull and update from the default repo"
			task( :pull, &method(:do_hg_pull) )

			desc "Pull and update without confirmation"
			task( :pull_without_confirmation, &method(:do_hg_pull_without_confirmation) )

			desc "Update to tip"
			task( :update, &method(:do_hg_update) )

			desc "Clobber all changes (hg up -C)"
			task( :update_and_clobber, &method(:do_hg_update_and_clobber) )

			desc "Mercurial-specific pre-checkin hook"
			task :precheckin => [ :pull, :newfiles, :check_for_changes ]

			desc "Check the current code in if tests pass"
			task( :checkin => COMMIT_MSG_FILE.to_s, &method(:do_hg_checkin) )

			desc "Mercurial-specific pre-release hook"
			task :prerelease => 'hg:check_history'

			desc "Mercurial-specific post-release hook"
			task( :postrelease, &method(:do_hg_postrelease) )

			desc "Push to the default origin repo (if there is one)"
			task( :push, &method(:do_hg_push) )

			desc "Push to the default repo without confirmation"
			task :push_without_confirmation do |task, args|
				self.hg.push
			end

			desc "Check the history file to ensure it contains an entry for each release tag"
			task( :check_history, &method(:do_hg_check_history) )

			desc "Generate and edit a new version entry in the history file"
			task( :update_history, &method(:do_hg_update_history) )

			task( :check_for_changes, &method(:do_hg_check_for_changes) )
			task( :debug, &method(:do_hg_debug) )
		end


		# Hook some generic tasks to the mercurial-specific ones
		task :checkin => 'hg:checkin'
		task :precheckin => 'hg:precheckin'

		task :prerelease => 'hg:prerelease'
		task :postrelease => 'hg:postrelease'

		desc "Update the history file with the changes since the last version tag."
		task :update_history => 'hg:update_history'

		task :debug => 'hg:debug'
	rescue ::Exception => err
		$stderr.puts "%s while defining Mercurial tasks: %s" % [ err.class.name, err.message ]
		raise
	end


	### Returns +true+ if the current directory looks like a Mercurial working copy.
	def is_hg_working_copy?
		return File.directory?( '.hg' )
	end


	### The body of the hg:prerelease task.
	def do_hg_prerelease( task, args )
		uncommitted_files = self.hg.status( n: true )
		unless uncommitted_files.empty?
			self.show_hg_file_statuses( uncommitted_files )

			fail unless self.prompt.yes?( "Release anyway?" ) do |q|
				q.default( false )
			end

			self.prompt.warn "Okay, releasing with uncommitted versions."
		end

		pkg_version_tag = self.current_hg_version_tag
		rev = self.hg.identity.id

		# Look for a tag for the current release version, and if it exists abort
		if self.hg.tags.find {|tag| tag.name == pkg_version_tag }
			self.prompt.error "Version #{self.version} already has a tag."
			fail
		end

		# Tag the current rev
		self.prompt.ok "Tagging rev %s as %s" % [ rev, pkg_version_tag ]
		self.hg.tag( pkg_version_tag, rev: rev )

		# Sign the tag
		if self.hg.extension_enabled?( :gpg )
			if self.prompt.yes?( "Sign %s?" % [pkg_version_tag] )
				self.hg.sign( pkg_version_tag, message: "Signing %s" % [pkg_version_tag] )
			end
		end
	end


	### The body of the hg:postrelease task.
	def do_hg_postrelease( task, args )
		if self.hg.status( 'checksum', unknown: true ).any?
			self.prompt.say "Adding release artifacts..."
			self.hg.add( 'checksum' )
			self.hg.commit( 'checksum', message: "Adding release checksum." )
		end

		if self.prompt.yes?( "Move released changesets to public phase?" )
			self.prompt.say "Publicising changesets..."
			self.hg.phase( public: true )
		end

		if self.hg.extension_enabled?( :topic )
			current_topic = self.hg.topic
			if current_topic && self.prompt.yes?( "Clear the current topic (%s)?" %[current_topic] )
				self.hg.topic( clear: true )
			end
		end

		Rake::Task['hg:push'].invoke
	end


	### The body of the hg:newfiles task.
	def do_hg_newfiles( task, args )
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
	def do_hg_pull( task, args )
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
	def do_hg_pull_without_confirmation( task, args )
		self.hg.pull
	end


	### The body of the hg:update task.
	def do_hg_update( task, args )
		self.hg.pull_update
	end


	### The body of the hg:update_and_clobber task.
	def do_hg_update_and_clobber( task, args )
		self.hg.update( clean: true )
	end


	### The body of the checkin task.
	def do_hg_checkin( task, args )
		targets = args.extras
		commit_msg = COMMIT_MSG_FILE.read.strip

		self.prompt.say( "---", color: :cyan )
		self.prompt.say( commit_msg )
		self.prompt.say( "---", color: :cyan )

		if self.prompt.yes?( "Continue with checkin?" )
			self.hg.commit( *targets, logfile: COMMIT_MSG_FILE.to_s )
			rm_f COMMIT_MSG_FILE
		else
			abort
		end
		Rake::Task[ 'hg:push' ].invoke
	end


	### The body of the push task.
	def do_hg_push( task, args )
		paths = self.hg.paths
		if origin_url = paths[:default]
			if self.prompt.yes?( "Push to '#{origin_url}'?" ) {|q| q.default(false) }
				self.hg.push
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
	def do_hg_check_history( task, args )
		unless self.history_file.readable?
			self.prompt.error "History file is missing or unreadable."
			abort
		end

		self.prompt.say "Checking history..."
		missing_tags = self.get_hg_unhistoried_version_tags

		unless missing_tags.empty?
			self.prompt.error "%s needs updating; missing entries for tags: %s" %
				[ self.history_file, missing_tags.join(', ') ]
			abort
		end
	end


	### Check the status of the repo and ensure there are outstanding changes. If there
	### are no changes, abort.
	def do_hg_check_for_changes( task, args )
		unless self.hg.dirty?
			self.prompt.error "Working copy is clean."
			abort
		end
	end


	### Generate a new history file entry for the current version.
	def do_hg_update_history( task, args ) # Needs refactoring
		unless self.history_file.readable?
			self.prompt.error "History file is missing or unreadable."
			abort
		end

		version_tag = self.current_hg_version_tag
		previous_tag = self.previous_hg_version_tag
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
				self.hg.log( rev: "#{previous_tag}~-2::" )
			else
				self.hg.log
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
				tmp_copy.puts "- %s" % [ entry.summary ]
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
	def do_hg_debug( task, args )
		self.prompt.say( "Hg Info", color: :bright_green )

		if self.is_hg_working_copy?
			self.prompt.say( "Mercurial version: " )
			self.prompt.say( Hglib.version, color: :bold )
			self.prompt.say( "Release tag prefix: " )
			self.prompt.say( self.release_tag_prefix, color: :bold )

			self.prompt.say( "Version tags:" )
			self.get_hg_version_tag_names.each do |tag|
				self.prompt.say( '- ' )
				self.prompt.say( tag, color: :bold )
			end

			self.prompt.say( "History file versions:" )
			self.get_history_file_versions.each do |tag|
				self.prompt.say( '- ' )
				self.prompt.say( tag, color: :bold )
			end

			self.prompt.say( "Unhistoried version tags:" )
			self.get_hg_unhistoried_version_tags.each do |tag|
				self.prompt.say( '- ' )
				self.prompt.say( tag, color: :bold )
			end
		else
			self.prompt.say( "Doesn't appear to be a Mercurial repository." )
		end

		self.prompt.say( "\n" )
	end

	#
	# utility methods
	#

	### Return an Hglib::Repo for the directory rake was invoked in, creating it if
	### necessary.
	def hg
		@hg ||= Hglib.repo( Rake::DevEiate::PROJECT_DIR )
	end


	### Given a +status_hash+ like that returned by Hglib::Repo.status, return a
	### string description of the files and their status.
	def show_hg_file_statuses( statuses )
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
	def current_hg_version_tag
		return [ self.release_tag_prefix, self.version ].join
	end


	### Fetch the name of the tag for the previous version.
	def previous_hg_version_tag
		return self.get_hg_version_tag_names.first
	end


	### Fetch the list of names of tags that match the versioning scheme of this
	### project.
	def get_hg_version_tag_names
		tag_pattern = /#{self.release_tag_pattern}$/
		return self.hg.tags.map( &:name ).grep( tag_pattern )
	end


	### Read the list of tags and return any that don't have a corresponding section
	### in the history file.
	def get_hg_unhistoried_version_tags( include_current_version: true )
		release_tags = self.get_hg_version_tag_names
		release_tags.unshift( self.current_hg_version_tag ) if include_current_version

		self.get_history_file_versions.each do |tag|
			release_tags.delete( tag )
		end

		return release_tags
	end


	### Generate a commit log and invoke the user's editor on it.
	def hg_edit_commit_log( logfile )
		diff = self.hg.diff

		TTY::Editor.open( logfile, text: diff )
	end


	### Add the list of +pathnames+ to the .hgignore list.
	def hg_ignore_files( *pathnames )
		patterns = pathnames.flatten.collect do |path|
			'^' + Regexp.escape( path.to_s ) + '$'
		end
		self.trace "Ignoring %d files." % [ pathnames.length ]

		IGNORE_FILE.open( File::CREAT|File::WRONLY|File::APPEND, 0644 ) do |fh|
			fh.puts( patterns )
		end
	end

end # module Rake::DevEiate::Hg


