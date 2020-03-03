# -*- ruby -*-
# frozen_string_literal: true

require 'rake'
require 'hglib'

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Fixup and conversion tasks
module Rake::DevEiate::Fixup
	extend Rake::DSL


	# Pattern for matching lines in the Manifest that shouldn't be there
	MANIFEST_CRUFT_LINE = %r{
		^(?:			# Match whole lines
			changelog
		)$
	}xim

	# Pathnames of Bundler-related files
	BUNDLER_FILES = [
		Rake::DevEiate::PROJECT_DIR + 'Gemfile',
		Rake::DevEiate::PROJECT_DIR + 'Gemfile.lock',
		Rake::DevEiate::PROJECT_DIR + 'Gemfile.devel',
		Rake::DevEiate::PROJECT_DIR + 'Gemfile.devel.lock',
	]

	# Pathnames of legacy dependency files
	LEGACY_DEPSFILES = [
		Rake::DevEiate::PROJECT_DIR + '.gems',
		Rake::DevEiate::PROJECT_DIR + '.rvm.gems',
	]

	# Gems to add to the 'development' group of the deps file
	DEV_GEMDEPS = %w[
		rake-deveiate
		rdoc-generator-fivefish
	]


	### Define fixup tasks
	def define_tasks
		super if defined?( super )

		self.define_hoe_fixup_tasks
	end


	### Set up tasks that check for poor whitespace discipline
	def define_hoe_fixup_tasks

		desc "Perform various fixup tasks on the current project."
		task :fixup => 'fixup:all'

		namespace :fixup do

			task :all => [
				:rakefile,
				:manifest,
				:bundler,
				:depsfiles,
			]

			desc "Remove hoe from the Rakefile and re-generate it"
			task :rakefile, &method( :do_fixup_rakefile )


			desc "Clean up cruft from the manifest file"
			task :manifest, &method( :do_fixup_manifest )


			desc "Remove Bundler-related files"
			task :bundler, &method( :do_fixup_bundler )


			desc "Fix up dependencies file/s"
			task :depsfiles, &method( :do_fixup_legacy_depsfiles )

		end

		task :fixup_debug, &method( :do_fixup_debug )
		task :debug => :fixup_debug
	end



	### Task function -- output debugging for fixup tasks.
	def do_fixup_debug( task, args )
		fixups = []

		fixups << "De-hoeify the Rakefile" if self.rakefile_needs_hoe_fixup?
		fixups << "Remove cruft from the manifest" if self.manifest_needs_fixup?
		fixups << "Remove bundler files" if self.bundler_files_present?
		fixups << "Convery legacy dependency files" if self.legacy_deps_files_present?

		self.prompt.say( "Fixups available:", color: :bright_green )

		if fixups.empty?
			self.prompt.say( "None; project looks clean." )
		else
			fixups.each do |desc|
				self.prompt.say "[ ] %s" % [ desc ]
			end
		end

		self.prompt.say( "\n" )
	end


	### Return +true+ if the Rakefile in the current project directory needs to be
	### cleaned up.
	def rakefile_needs_hoe_fixup?
		return false unless self.rakefile.exist? && !self.rakefile.zero?
		return self.rakefile.read.split( /^__END__/m, 2 ).first.match?( /hoe/i )
	end


	### Returns +true+ if the manifest file has crufty lines in it.
	def manifest_needs_fixup?
		return false unless self.manifest_file.exist?
		return self.manifest_file.each_line.any?( MANIFEST_CRUFT_LINE )
	end


	### Return +true+ if there are Bundler-related files in the project.
	def bundler_files_present?
		return BUNDLER_FILES.any?( &:exist? )
	end


	### Return +true+ if there are legacy dependency files in the project
	def legacy_deps_files_present?
		return LEGACY_DEPSFILES.any?( &:exist? )
	end


	### Replace the current Rakefile with a generated one of it is a Hoe-based one.
	def do_fixup_rakefile( task, * )
		unless self.rakefile_needs_hoe_fixup?
			self.trace "Not a hoe-based Rakefile; skipping"
			return
		end

		original = self.rakefile.read

		self.write_replacement_file( self.rakefile, encoding: 'utf-8' ) do |fh|

			self.trace "Re-generating Rakefile from a template"
			template = Rake::DevEiate::Generate::RAKEFILE_TEMPLATE
			boilerplate = self.load_and_render_template( template, 'Rakefile' )
			fh.print( boilerplate )

			self.trace "Appending the old Rakefile contents in an END section"
			fh.puts
			fh.puts "__END__"
			fh.puts
			fh.print( original )
		end
	end


	### Clean up cruft from the manifest file.
	def do_fixup_manifest( task, * )
		unless self.manifest_needs_fixup?
			self.trace "Manifest is clean; skipping"
			return
		end

		self.write_replacement_file( self.manifest_file, encoding: 'utf-8' ) do |fh|
			self.trace "Removing cruft from the manifest"
			self.manifest_file.each_line do |line|
				next if line.match?( MANIFEST_CRUFT_LINE )
				fh.puts( line )
			end
		end
	end


	### Remove any bundler-related files.
	def do_fixup_bundler( task, * )
		BUNDLER_FILES.each do |file|
			next unless file.exist?
			self.trace "Removing bundler file %s..." % [ file ]
			self.hg.rm( file, force: true )
		end
	end


	### Convert legacy dependency files to the newer form.
	def do_fixup_legacy_depsfiles( task, * )
		unless self.legacy_deps_files_present?
			self.trace "No legacy dependency files; skipping"
			return
		end

		new_depsfile = Rake::DevEiate::GEMDEPS_FILE

		LEGACY_DEPSFILES.each do |depsfile|
			next unless depsfile.readable?

			if new_depsfile.exist?
				self.hg.rm( depsfile )
			else
				depnames = depsfile.each_line.map do |line|
					line.split( /\s+/, 2 ).first
				end

				raise "Failed to read dependencies from %s!" % [ depsfile ] if depnames.empty?

				self.trace "Recording move of %s to %s" % [ depsfile, new_depsfile ]
				self.hg.mv( depsfile, new_depsfile )

				newest_deps = self.find_latest_versions( *depnames ).
					reject {|tuple| tuple.name.include?('hoe') }
				dev_deps = self.find_latest_versions( *DEV_GEMDEPS )

				self.write_replacement_file( new_depsfile, encoding: 'utf-8' ) do |fh|
					fh.puts "source 'https://rubygems.org/'"
					fh.puts

					newest_deps.each do |dep|
						fh.puts "gem '%s', '%s'" %
							[ dep.name, dep.version.approximate_recommendation ]
					end

					fh.puts
					fh.puts "group :development do"
					dev_deps.each do |dep|
						fh.puts "\tgem '%s', '%s'" %
							[ dep.name, dep.version.approximate_recommendation ]
					end
					fh.puts "end"
				end
			end
		end
	end


	### Find the latest version for the specified +gemnames+ and return them as Gem::Specifiations
	def find_latest_versions( *gemnames )
		pattern = /\A#{Regexp.union(gemnames)}\Z/
		fetcher = Gem::SpecFetcher.fetcher
		return fetcher.
			detect( :latest ) {|tuple| pattern =~ tuple.name && tuple.platform == 'ruby' }.
			transpose.first
	end

end # module Rake::DevEiate::Fixups


