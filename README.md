# Rake Tasks for DevEiate Libraries

home
: https://hg.sr.ht/~ged/rake-deveiate

code
: https://hg.sr.ht/~ged/rake-deveiate/browse

github
: https://github.com/ged/rake-deveiate

docs
: https://deveiate.org/code/rake-deveiate/


## Description

This is a collection of Rake tasks I use for development. I distribute them as
a gem mostly so people who wish to contribute to the other Open Source
libraries I maintain can do so easily, but of course you're welcome to use them
yourself if you find them useful.


## Prerequisites

* Ruby 2.6+


## Installation

    $ gem install rake-deveiate


## Usage

Make a Rakefile with the following content:

    require 'rake/deveiate'
    
    Rake::DevEiate.setup( 'gemname' )

You can also pass a block to customize the project settings:

    Rake::DevEiate.setup( 'gemname' ) do |project|
        project.description = <<~END_DESC
          This is a gem that does some stuff. It does a few things well, a lot of
          things sufficiently, and nothing badly.
        END_DESC
        project.authors = [ 'J. Random Hacker <jrandom@example.com>' ]
    end



## Authors

- Michael Granger <ged@FaerieMUD.org>


## License

Copyright (c) 2019, Michael Granger
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the author/s, nor the names of the project's
  contributors may be used to endorse or promote products derived from this
  software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
