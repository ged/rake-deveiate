# -*- ruby -*-
# frozen_string_literal: true

require 'rake'

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Sanity and quality check tasks
module Rake::DevEiate::Checks
	extend Rake::DSL

	# Emoji for style advisories
	SADFACE = "\u{1f622}"

	# Tab-arrow character
	TAB_ARROW = "\u{21e5}"

	# Regexp to match trailing whitespace
	TRAILING_WHITESPACE_RE = /\p{Blank}+$/m

	# Regexp to match lines with mixed indentation
	MIXED_INDENT_RE = /(?<!#)([ ]\t)/


	### Set up task defaults
	def setup( _name, **options )
		super if defined?( super )

		@quality_check_whitelist = Rake::FileList.new
	end


	##
	# The Rake::FileList containing files which should not be quality-checked.
	attr_reader :quality_check_whitelist


	### Define check tasks
	def define_tasks
		super if defined?( super )

		self.define_quality_checker_tasks
		self.define_sanity_checker_tasks

		desc "Run several quality-checks on the code"
		task :quality_checks => [ 'quality_checks:all' ]

		desc "Run several sanity-checks on the code"
		task :sanity_checks => [ 'sanity_checks:all' ]

		task :check => [ :quality_checks, :sanity_checks ]

	end


	### Set up tasks that check for poor whitespace discipline
	def define_quality_checker_tasks

		namespace :quality_checks do

			task :all => [ :whitespace ]

			desc "Check source code for inconsistent whitespace"
			task :whitespace => [
				:for_trailing_whitespace,
				:for_mixed_indentation,
			]

			desc "Check source code for trailing whitespace"
			task :for_trailing_whitespace do
				lines = find_matching_source_lines do |line, _|
					line =~ TRAILING_WHITESPACE_RE
				end

				unless lines.empty?
					desc = "Found some trailing whitespace"
					describe_lines_that_need_fixing( desc, lines, TRAILING_WHITESPACE_RE )
					fail
				end
			end

			desc "Check source code for mixed indentation"
			task :for_mixed_indentation do
				lines = find_matching_source_lines do |line, _|
					line =~ MIXED_INDENT_RE
				end

				unless lines.empty?
					desc = "Found mixed indentation"
					describe_lines_that_need_fixing( desc, lines, /[ ]\t/ )
					fail
				end
			end

		end

	end


	### Set up some sanity-checks as dependencies of higher-level tasks
	def define_sanity_checker_tasks

		namespace :sanity_checks do

			desc "Check source code for common problems"
			task :all

		end

	end


	# Return tuples of the form:
	#
	#   [ <filename>, <line number>, <line> ]
	#
	# for every line in the Gemspec's source files for which the block
	# returns true.
	def find_matching_source_lines
		matches = []

		source_files = self.project_files.grep( /\.(h|c|rb)$/ )
		source_files -= self.quality_check_whitelist

		source_files.each do |filename|
			previous_line = nil

			IO.foreach( filename ).with_index do |line, i|
				matches << [filename, i + 1, line] if yield( line, previous_line )
				previous_line = line
			end
		end

		return matches
	end


	### Output a listing of the specified lines with the given +description+, highlighting
	### the characters matched by the specified +re+.
	def describe_lines_that_need_fixing( description, lines, re )
		self.prompt.say "\n"
		self.prompt.say SADFACE + "  "
		self.prompt.error( "Uh-oh! " + description )

		grouped_lines = group_line_matches( lines )

		grouped_lines.each do |filename, linegroups|
			linegroups.each do |group, lines|
				if group.min == group.max
					self.prompt.say( "%s:%d" % [ filename, group.min ], color: :bold )
				else
					self.prompt.say( "%s:%d-%d" % [ filename, group.min, group.max ], color: :bold )
				end

				lines.each_with_index do |line, i|
					self.prompt.say "%s: %s" % [
						self.pastel.dark.white( group.to_a[i].to_s ),
						highlight_problems( line, re )
					]
				end
				self.prompt.say "\n"
			end
		end
	end


	# Return a Hash, keyed by filename, whose values are tuples of Ranges
	# and lines extracted from the given [filename, linenumber, line] +tuples+.
	def group_line_matches( tuples )
		by_file = tuples.group_by {|tuple| tuple.first }

		return by_file.each_with_object({}) do |(filename, lines), hash|
			last_linenum = 0
			linegroups = lines.slice_before do |filename, linenum|
				gap = linenum > last_linenum + 1
				last_linenum = linenum
				gap
			end

			hash[ filename ] = linegroups.map do |group|
				rng = group.first[1] .. group.last[1]
				grouplines = group.transpose.last
				[ rng, grouplines ]
			end
		end
	end


	### Transform invisibles in the specified line into visible analogues.
	def highlight_problems( line, re )
		line.
			gsub( re )    { self.pastel.on_red( $& ) }.
			gsub( /\t+/ ) { self.pastel.dark.white( "#{TAB_ARROW}   " * $&.length ) }
	end


end # module Rake::DevEiate::Checks


