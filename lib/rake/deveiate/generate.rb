# -*- ruby -*-
# frozen_string_literal: true

require 'erb'

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Project-file generation tasks
module Rake::DevEiate::Generate


	# Template files
	README_TEMPLATE = Rake::DevEiate::DEVEIATE_DATADIR + 'README.erb'
	HISTORY_TEMPLATE = Rake::DevEiate::DEVEIATE_DATADIR + 'History.erb'

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
		template_src = template_path.read( encoding: 'utf-8' )
		template = ERB.new( template_src, trim_mode: '-' )

		header_char = self.header_char_for( filename )

		self.prompt.ok "Generating #{filename}..."
		File.open( filename, FILE_CREATION_FLAGS, 0644, encoding: 'utf-8' ) do |io|
			result = template.result_with_hash(
				header_char: header_char,
				project: self
			)
			io.print( result )
		end
	end


	### Return the character used to build headings give the filename of the file to
	### be generated.
	def header_char_for( filename )
		case File.extname( filename )
		when '.md' then return '#'
		when '.rdoc' then return '='
		else
			raise "Don't know what header character is appropriate for %s" % [ filename ]
		end
	end

end # module Rake::DevEiate::Hg


