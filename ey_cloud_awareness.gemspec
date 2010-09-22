# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{ey_cloud_awareness}
  s.version = "0.1.14"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Seamus Abshere"]
  s.date = %q{2010-09-22}
  s.default_executable = %q{ey_cloud_awareness}
  s.description = %q{Pull metadata from EC2 and EngineYard so that your EngineYard Cloud instances know about each other.}
  s.email = %q{seamus@abshere.net}
  s.executables = ["ey_cloud_awareness"]
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "bin/ey_cloud_awareness",
     "ey_cloud_awareness.gemspec",
     "lib/ey_cloud_awareness.rb",
     "lib/ey_cloud_awareness/capistrano_tasks.rb",
     "lib/ey_cloud_awareness/engine_yard_cloud_instance.rb",
     "lib/ey_cloud_awareness/hash_ext.rb",
     "spec/ey_cloud_awareness_spec.rb",
     "spec/spec.opts",
     "spec/spec_helper.rb"
  ]
  s.homepage = %q{http://github.com/seamusabshere/ey_cloud_awareness}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Make your EngineYard cloud instances aware of each other.}
  s.test_files = [
    "spec/ey_cloud_awareness_spec.rb",
     "spec/spec_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<string_replacer>, [">= 0.0.1"])
      s.add_runtime_dependency(%q<activesupport>, [">= 2.3.4"])
      s.add_runtime_dependency(%q<amazon-ec2>, [">= 0.9.15"])
    else
      s.add_dependency(%q<string_replacer>, [">= 0.0.1"])
      s.add_dependency(%q<activesupport>, [">= 2.3.4"])
      s.add_dependency(%q<amazon-ec2>, [">= 0.9.15"])
    end
  else
    s.add_dependency(%q<string_replacer>, [">= 0.0.1"])
    s.add_dependency(%q<activesupport>, [">= 2.3.4"])
    s.add_dependency(%q<amazon-ec2>, [">= 0.9.15"])
  end
end

