# -*- encoding: utf-8 -*-
# stub: rake-deveiate 0.20.0.pre.20210715103154 ruby lib

Gem::Specification.new do |s|
  s.name = "rake-deveiate".freeze
  s.version = "0.20.0.pre.20210715103154"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://todo.sr.ht/~ged/rake-deveiate/browse", "changelog_uri" => "https://deveiate.org/code/rake-deveiate/History_md.html", "documentation_uri" => "https://deveiate.org/code/rake-deveiate/", "homepage_uri" => "https://hg.sr.ht/~ged/rake-deveiate", "source_uri" => "https://hg.sr.ht/~ged/rake-deveiate/browse" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Michael Granger".freeze]
  s.date = "2021-07-15"
  s.description = "This is a collection of Rake tasks I use for development. I distribute them as a gem mostly so people who wish to contribute to the other Open Source libraries I maintain can do so easily, but of course you&#39;re welcome to use them yourself if you find them useful.".freeze
  s.email = ["ged@FaerieMUD.org".freeze]
  s.files = ["History.md".freeze, "README.md".freeze, "data/rake-deveiate".freeze, "data/rake-deveiate/History.erb".freeze, "data/rake-deveiate/README.erb".freeze, "data/rake-deveiate/Rakefile.erb".freeze, "data/rake-deveiate/global.rake".freeze, "lib/rake/deveiate.rb".freeze, "lib/rake/deveiate/checks.rb".freeze, "lib/rake/deveiate/docs.rb".freeze, "lib/rake/deveiate/extensions.rb".freeze, "lib/rake/deveiate/fixup.rb".freeze, "lib/rake/deveiate/gem_dep_finder.rb".freeze, "lib/rake/deveiate/gemspec.rb".freeze, "lib/rake/deveiate/generate.rb".freeze, "lib/rake/deveiate/git-refinements.rb".freeze, "lib/rake/deveiate/git.rb".freeze, "lib/rake/deveiate/hg.rb".freeze, "lib/rake/deveiate/packaging.rb".freeze, "lib/rake/deveiate/releases.rb".freeze, "lib/rake/deveiate/specs.rb".freeze]
  s.homepage = "https://hg.sr.ht/~ged/rake-deveiate".freeze
  s.licenses = ["BSD-3-Clause".freeze]
  s.rubygems_version = "3.2.15".freeze
  s.summary = "This is a collection of Rake tasks I use for development.".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<rake>.freeze, ["~> 13.0"])
    s.add_runtime_dependency(%q<rdoc>.freeze, ["~> 6.3"])
    s.add_runtime_dependency(%q<rspec>.freeze, ["~> 3.8"])
    s.add_runtime_dependency(%q<simplecov>.freeze, ["~> 0.18"])
    s.add_runtime_dependency(%q<hglib>.freeze, ["~> 0.11"])
    s.add_runtime_dependency(%q<tty-prompt>.freeze, ["~> 0.19"])
    s.add_runtime_dependency(%q<tty-editor>.freeze, ["~> 0.6"])
    s.add_runtime_dependency(%q<tty-table>.freeze, ["~> 0.11"])
    s.add_runtime_dependency(%q<pastel>.freeze, ["~> 0.7"])
    s.add_runtime_dependency(%q<git>.freeze, ["~> 1.7"])
    s.add_runtime_dependency(%q<net-scp>.freeze, ["~> 3.0"])
    s.add_runtime_dependency(%q<ed25519>.freeze, ["~> 1.2"])
    s.add_runtime_dependency(%q<bcrypt_pbkdf>.freeze, ["~> 1.1"])
    s.add_development_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.4"])
  else
    s.add_dependency(%q<rake>.freeze, ["~> 13.0"])
    s.add_dependency(%q<rdoc>.freeze, ["~> 6.3"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.8"])
    s.add_dependency(%q<simplecov>.freeze, ["~> 0.18"])
    s.add_dependency(%q<hglib>.freeze, ["~> 0.11"])
    s.add_dependency(%q<tty-prompt>.freeze, ["~> 0.19"])
    s.add_dependency(%q<tty-editor>.freeze, ["~> 0.6"])
    s.add_dependency(%q<tty-table>.freeze, ["~> 0.11"])
    s.add_dependency(%q<pastel>.freeze, ["~> 0.7"])
    s.add_dependency(%q<git>.freeze, ["~> 1.7"])
    s.add_dependency(%q<net-scp>.freeze, ["~> 3.0"])
    s.add_dependency(%q<ed25519>.freeze, ["~> 1.2"])
    s.add_dependency(%q<bcrypt_pbkdf>.freeze, ["~> 1.1"])
    s.add_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.4"])
  end
end
