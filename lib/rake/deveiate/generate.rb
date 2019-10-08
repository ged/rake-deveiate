# -*- ruby -*-
# frozen_string_literal: true

require 'erb'

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Project-file generation tasks
module Rake::DevEiate::Generate


	# Template files
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

		file( self.readme_file.to_s )
		file( self.history_file.to_s )
		file( self.manifest_file.to_s )
		file( RUBY_VERSION_FILE.to_s )
		file( GEMSET_FILE.to_s )

		task( self.readme_file, &method(:do_generate_readme_file) )
		task( self.history_file, &method(:do_generate_history_file) )
		task( self.manifest_file, &method(:do_generate_manifest_file) )
		task( RUBY_VERSION_FILE, &method(:do_generate_ruby_version_file) )
		task( GEMSET_FILE, &method(:do_generate_gemset_file) )

		task :generate => [
			self.readme_file,
			self.history_file,
			self.manifest_file,
			RUBY_VERSION_FILE,
			GEMSET_FILE,
		]
	end



	### Generate a README file if one doesn't already exist. Error if one does.
	def do_generate_readme_file( task, *args )
		self.generate_from_template( task.name, README_TEMPLATE )
	end



	### Generate a History file if one doesn't already exist. Error if one does.
	def do_generate_history_file( task, *args )
		self.generate_from_template( task.name, HISTORY_TEMPLATE )
	end


	### Generate a manifest with a default set of files listed.
	def do_generate_manifest_file( task, *args )
		self.prompt.ok "Generating #{task.name}..."
		File.open( task.name, FILE_CREATION_FLAGS, 0644, encoding: 'utf-8' ) do |io|
			io.puts( *self.project_files )
		end
	end


	### Generate a file that sets the project's working Ruby version.
	def do_generate_ruby_version_file( task, *args )
		self.prompt.ok "Generating #{task.name}..."
		File.open( task.name, FILE_CREATION_FLAGS, 0644, encoding: 'utf-8' ) do |io|
			io.puts( RUBY_VERSION.sub(/\.\d+$/, '') )
		end
	end


	### Generate a file that sets the project's gemset
	def do_generate_gemset_file( task, *args )
		self.prompt.ok "Generating #{task.name}..."
		File.open( task.name, FILE_CREATION_FLAGS, 0644, encoding: 'utf-8' ) do |io|
			io.puts( self.name )
		end
	end


	### Generate the given +filename+ from the template filed at +template_path+.
	def generate_from_template( filename, template_path )
		self.prompt.ok "Generating #{filename}..."
		File.open( filename, FILE_CREATION_FLAGS, 0644, encoding: 'utf-8' ) do |io|
			result = self.load_and_render_template( template_path )
			io.print( result )
		end
	end

end # module Rake::DevEiate::Hg


