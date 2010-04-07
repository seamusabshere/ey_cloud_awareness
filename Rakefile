require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "ey_cloud_awareness"
    gem.summary = %Q{Make your EngineYard cloud instances aware of each other.}
    gem.description = %Q{Make your EngineYard cloud instances aware of each other.}
    gem.email = "seamus@abshere.net"
    gem.homepage = "http://github.com/seamusabshere/ey_cloud_awareness"
    gem.authors = ["Seamus Abshere"]
    # gem.rubyforge_project = "ey_cloud_awareness"
    gem.add_dependency 'json', '>=1.2.3'
    gem.add_dependency 'activesupport', '>=2.3.4'
    gem.add_dependency 'right_aws', '1.10.0' # static because of my hack
    gem.add_development_dependency "rspec", ">= 1.2.9"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
  Jeweler::RubyforgeTasks.new do |rubyforge|
    rubyforge.doc_task = "rdoc"
  end
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :spec => :check_dependencies

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "ey_cloud_awareness #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
