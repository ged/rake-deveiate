# -*- encoding: utf-8 -*-
# stub: rake-deveiate 0.2.0.pre.20191001191107 ruby lib

Gem::Specification.new do |s|
  s.name = "rake-deveiate".freeze
  s.version = "0.2.0.pre.20191001191107"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Michael Granger".freeze]
  s.date = "2019-10-02"
  s.description = "This is a collection of Rake tasks I use for development. I distribute them as a gem mostly so people who wish to contribute to them can do so easily, but of course you're welcome to use them yourself if you find them useful.".freeze
  s.email = ["ged@FaerieMUD.org".freeze]
  s.files = ["README.md".freeze, "data/rake-deveiate".freeze]
  s.licenses = ["BSD-3-Clause".freeze]
  s.rubygems_version = "3.0.3".freeze
  s.summary = "This is a collection of Rake tasks I use for development.".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rake>.freeze, ["~> 12.3"])
      s.add_runtime_dependency(%q<rdoc>.freeze, ["~> 6.2"])
      s.add_runtime_dependency(%q<rspec>.freeze, ["~> 3.8"])
      s.add_runtime_dependency(%q<hglib>.freeze, ["~> 0.2"])
      s.add_runtime_dependency(%q<tty-prompt>.freeze, ["~> 0.19"])
      s.add_runtime_dependency(%q<tty-editor>.freeze, ["~> 0.5"])
      s.add_runtime_dependency(%q<tty-table>.freeze, ["~> 0.11"])
      s.add_runtime_dependency(%q<pastel>.freeze, ["~> 0.7"])
      s.add_runtime_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.4"])
    else
      s.add_dependency(%q<rake>.freeze, ["~> 12.3"])
      s.add_dependency(%q<rdoc>.freeze, ["~> 6.2"])
      s.add_dependency(%q<rspec>.freeze, ["~> 3.8"])
      s.add_dependency(%q<hglib>.freeze, ["~> 0.2"])
      s.add_dependency(%q<tty-prompt>.freeze, ["~> 0.19"])
      s.add_dependency(%q<tty-editor>.freeze, ["~> 0.5"])
      s.add_dependency(%q<tty-table>.freeze, ["~> 0.11"])
      s.add_dependency(%q<pastel>.freeze, ["~> 0.7"])
      s.add_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.4"])
    end
  else
    s.add_dependency(%q<rake>.freeze, ["~> 12.3"])
    s.add_dependency(%q<rdoc>.freeze, ["~> 6.2"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.8"])
    s.add_dependency(%q<hglib>.freeze, ["~> 0.2"])
    s.add_dependency(%q<tty-prompt>.freeze, ["~> 0.19"])
    s.add_dependency(%q<tty-editor>.freeze, ["~> 0.5"])
    s.add_dependency(%q<tty-table>.freeze, ["~> 0.11"])
    s.add_dependency(%q<pastel>.freeze, ["~> 0.7"])
    s.add_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.4"])
  end
end
