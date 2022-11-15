# -*- ruby -*-
# frozen_string_literal: true

require 'tempfile'
require 'erb'

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Project-file generation tasks
module Rake::DevEiate::Generate


	# Template files
	RAKEFILE_TEMPLATE = 'Rakefile.erb'
	README_TEMPLATE = 'README.erb'
	HISTORY_TEMPLATE = 'History.erb'

	# RVM metadata files
	RUBY_VERSION_FILE = Rake::DevEiate::PROJECT_DIR + '.ruby-version'
	GEMSET_FILE = Rake::DevEiate::PROJECT_DIR + '.ruby-gemset'

	# Flags to use when opening a file for generation
	FILE_CREATION_FLAGS = File::WRONLY | File::CREAT | File::EXCL


	### Define generation tasks.
	def define_tasks
		super if defined?( super )

		file( self.rakefile.to_s )
		file( self.readme_file.to_s )
		file( self.history_file.to_s )
		file( self.manifest_file.to_s )
		file( RUBY_VERSION_FILE.to_s )
		file( GEMSET_FILE.to_s )

		task( self.rakefile, &method(:do_generate_rakefile) )
		task( self.readme_file, &method(:do_generate_readme_file) )
		task( self.history_file, &method(:do_generate_history_file) )
		task( self.manifest_file, &method(:do_generate_manifest_file) )
		task( RUBY_VERSION_FILE, &method(:do_generate_ruby_version_file) )
		task( GEMSET_FILE, &method(:do_generate_gemset_file) )

		desc "Generate any missing project files."
		task :generate => [
			self.rakefile,
			self.readme_file,
			self.history_file,
			self.manifest_file,
			RUBY_VERSION_FILE,
			GEMSET_FILE,
		]

		# Abstract named tasks; mostly for invoking programmatically
		namespace :generate do

			desc "Generate a Rakefile"
			task :rakefile => self.rakefile

			desc "Generate a %s file" % [ self.readme_file ]
			task :readme => self.readme_file

			desc "Generate a %s file" % [ self.history_file ]
			task :history_file => self.history_file

			desc "Generate a %s file" % [ self.manifest_file ]
			task :manifest => self.manifest_file

			desc "Generate a %s file" % [ RUBY_VERSION_FILE ]
			task :ruby_version_file => RUBY_VERSION_FILE

			desc "Generate a %s file" % [ GEMSET_FILE ]
			task :gemset_file => GEMSET_FILE
		end

		desc "Diff the manifest file against the default set of project files."
		task( :diff_manifest, &method(:do_diff_manifest) )
	end


	### Generate a Rakefile if one doesn't already exist. Error if one does.
	def do_generate_rakefile( task, args )
		self.generate_from_template( task.name, RAKEFILE_TEMPLATE )
	end


	### Generate a README file if one doesn't already exist. Error if one does.
	def do_generate_readme_file( task, args )
		self.generate_from_template( task.name, README_TEMPLATE )
	end



	### Generate a History file if one doesn't already exist. Error if one does.
	def do_generate_history_file( task, args )
		self.generate_from_template( task.name, HISTORY_TEMPLATE )
	end


	### Generate a manifest with a default set of files listed.
	def do_generate_manifest_file( task, args )
		self.prompt.ok "Generating #{task.name}..."
		File.open( task.name, FILE_CREATION_FLAGS, 0644, encoding: 'utf-8' ) do |io|
			io.puts( *self.project_files )
		end
	end


	### Generate a file that sets the project's working Ruby version.
	def do_generate_ruby_version_file( task, args )
		self.prompt.ok "Generating #{task.name}..."
		File.open( task.name, FILE_CREATION_FLAGS, 0644, encoding: 'utf-8' ) do |io|
			io.puts( RUBY_VERSION.sub(/\.\d+$/, '') )
		end
	end


	### Generate a file that sets the project's gemset
	def do_generate_gemset_file( task, args )
		self.prompt.ok "Generating #{task.name}..."
		File.open( task.name, FILE_CREATION_FLAGS, 0644, encoding: 'utf-8' ) do |io|
			io.puts( self.name )
		end
	end


	### Task body for the `diff_manifest` task
	def do_diff_manifest( task, args )
		Tempfile.open( ['Manifest','.txt'], Rake::DevEiate::PROJECT_DIR ) do |io|
			file_list = self.default_manifest.select {|pn| File.file?(pn) }.sort

			io.puts( *file_list )
			io.flush

			sh 'diff', '-ub', self.manifest_file.to_s, io.path
		end
	end


	### Generate the given +filename+ from the template filed at +template_path+.
	def generate_from_template( filename, template_path )
		self.prompt.ok "Generating #{filename}..."
		File.open( filename, FILE_CREATION_FLAGS, 0644, encoding: 'utf-8' ) do |io|
			result = self.load_and_render_template( template_path, filename )
			io.print( result )
		end
	end

end # module Rake::DevEiate::Generate


