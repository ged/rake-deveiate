# -*- ruby -*-
# frozen_string_literal: true

begin
	require 'rake/deveiate'
rescue LoadError => err
	msg = err.respond_to?( :full_message ) ?
		err.full_message( highlight: true, order: :bottom ) :
		err.message
	warn "%p while loading rake-deveiate: %s" % [ err.class, msg ]
end


if defined?( Rake::DevEiate ) && !Rake::DevEiate.already_setup?
	default_name = File.basename( Dir.pwd ).downcase

	Rake::DevEiate.setup( default_name )

end


