# -*- ruby -*-
# frozen_string_literal: true

require 'erb'

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Project-file generation tasks
module Rake::DevEiate::Generate


	# Template files
	README_TEMPLATE = Rake::DevEiate::DEVEIATE_DATADIR + 'README.erb'
	HISTORY_TEMPLATE = Rake::DevEiate::DEVEIATE_DATADIR + 'History.erb'


	### Define generation tasks.
	def define_tasks
		super if defined?( super )

		namespace :generate do

			file( self.readme_file.to_s )
			file( self.history_file.to_s )

			task( self.readme_file, &method(:do_generate_readme_file) )
			task( self.history_file, &method(:do_generate_history_file) )
		end
	end



	### Generate a README file if one doesn't already exist. Error if one does.
	def do_generate_readme_file( task, *args )
		self.generate_from_template( task.name, README_TEMPLATE )
	end



	### Generate a History file if one doesn't already exist. Error if one does.
	def do_generate_history_file( task, *args )
		self.generate_from_template( task.name, HISTORY_TEMPLATE )
	end


	### Generate the given +filename+ from the template filed at +template_path+.
	def generate_from_template( filename, template_path )
		template_src = template_path.read( encoding: 'utf-8' )
		template = ERB.new( template_src, trim_mode: '>' )

		header_char = self.header_char_for( filename )

		self.prompt.ok "Generating #{filename}..."
		File.open( filename, File::WRONLY|File::CREAT|File::EXCL, 0644, encoding: 'utf-8' ) do |io|
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


