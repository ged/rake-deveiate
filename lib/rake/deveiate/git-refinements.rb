# -*- ruby -*-
# frozen_string_literal: true

require 'git'

require 'rake/deveiate' unless defined?( Rake::DevEiate )


# Monkeypatches to allow command options the `git` gem doesn't allow.
#
# Refs:
# - https://github.com/ruby-git/ruby-git/issues/394
module Rake::DevEiate::GitRefinements

	refine Git::Base do
		def cmd( cmd )
			self.lib.cmd( cmd )
		end
	end

	refine Git::Lib do
		def cmd( cmd )
			command( cmd )
		end
	end

end # module GitRefinements

