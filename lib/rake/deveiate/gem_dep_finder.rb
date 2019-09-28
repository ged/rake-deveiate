# -*- ruby -*-
# frozen_string_literal: true

require 'set'
require 'rubygems'
require 'rake/deveiate' unless defined?( Rake::DevEiate )


# A dependency finder that groks the GemDependencyApi
class Rake::DevEiate::GemDepFinder

	### Create a new GemDepFinder that will find dependencies in the given
	### +depfile+.
	def initialize( depfile )
		@depfile = Pathname( depfile )
		@dependencies = Set.new
		@current_groups = Set.new
	end



	######
	public
	######

	##
	# The Pathname of the file to find dependencies in
	attr_reader :depfile

	##
	# The Set of Gem::Dependency objects that describe the loaded dependencies
	attr_reader :dependencies

	##
	# The current set of groups to add to any declared gems
	attr_reader :current_groups


	### Load the dependencies file.
	def load
		source = self.depfile.read
		self.instance_eval( source, self.depfile.to_s, 1 )
	end


	#
	# Gem Dependency API methods
	#


	### Declare a dependency on a gem. Ignores every option except :group.
	def gem( name, *requirements, **options )
		if options[:group] == :development ||
			options[:groups]&.include?( :development ) ||
			self.current_groups.include?( :development )

			requirements.push( :development )
		end

		dependency = Gem::Dependency.new( name, *requirements )

		self.dependencies.add( dependency )
	end


	### Declare a group block.
	def group( *names )
		options = names.pop if names.last.is_a?( Hash )
		previous_groups = self.current_groups.dup
		self.current_groups.replace( names )

		yield
	ensure
		self.current_groups.replace( previous_groups ) if previous_groups
	end


	### Raise, as the gemdeps file should be the authoritative source.
	def gemspec( * )
		raise "Circular dependency: can't depend on the gemspec to build itself"
	end


	### Ignore a gem dependency API call.
	def no_op_method( * ) # :nodoc:
		yield if block_given?
	end

	alias_method :source, :no_op_method
	alias_method :git, :no_op_method
	alias_method :platform, :no_op_method
	alias_method :platforms, :no_op_method
	alias_method :ruby, :no_op_method


end # class Rake::DevEiate::GemDepFinder

