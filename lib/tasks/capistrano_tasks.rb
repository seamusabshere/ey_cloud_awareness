require 'ey_cloud_awareness'
require 'pp'

task :eyc_setup, :roles => :app_master do
  version = Gem.searcher.find('ey_cloud_awareness').version.to_s
  begin
    run "gem list ey_cloud_awareness --installed --version #{version}"
  rescue
    $stderr.puts "[EY CLOUD AWARENESS GEM] app_master doesn't have ey_cloud_awareness --version #{version} installed. You need to have the exact same version installed."
    raise $!
  end

  upload File.expand_path(File.join(File.dirname(__FILE__), 'ey_cloud_awareness.rake')), "#{deploy_to}/current/lib/tasks/ey_cloud_awareness.rake"
  
  output = capture("cd #{deploy_to}/current && rake --silent eyc:to_json RAILS_ENV=#{rails_env}").gsub(/\s+/, ' ')
  if /(\{.*\})/.match(output)
    begin
      set :eyc_proxy, EngineYardCloudInstance.from_hash(ActiveSupport::JSON.decode($1))
    rescue
      $stderr.puts "[EY CLOUD AWARENESS GEM] Couldn't parse JSON, so just dumping what we got"
      $stderr.puts $1
      raise $!
    end
  else
    $stderr.puts "[EY CLOUD AWARENESS GEM] Didn't get JSON we recognized back, just dumping what we got"
    $stderr.puts output
    raise
  end
  eyc_proxy.app.each { |i| role :app, i.dns_name }
  eyc_proxy.db.each { |i| role :db, i.dns_name }
end

namespace :eyc do
  %w{ app db utility all first }.each do |name|
    task name, :roles => :app_master do
      pp eyc_proxy.send(name).map(&:to_hash)
    end
  end
end

class StringReplacer
  NEWLINE = "AijQA6tD1wkWqgvLzXD"
  START_MARKER = '# START StringReplacer %s -- DO NOT MODIFY'
  END_MARKER = "# END StringReplacer %s -- DO NOT MODIFY#{NEWLINE}"
  
  attr_accessor :path
  def initialize(path)
    @path = path
  end
  
  def replace!(replacement, id = 1)
    new_path = "#{path}.new"
    backup_path = "#{path}.bak"
    current_start_marker = START_MARKER % id.to_s
    current_end_marker = END_MARKER % id.to_s
    replacement_with_markers = current_start_marker + NEWLINE + replacement + NEWLINE + current_end_marker
    text = IO.read(path).gsub("\n", NEWLINE)
    if text.include? current_start_marker
      text.gsub! /#{Regexp.escape current_start_marker}.*#{Regexp.escape current_end_marker}/, replacement_with_markers
    else
      text << NEWLINE << replacement_with_markers
    end
    text.gsub! NEWLINE, "\n"
    File.open(new_path, 'w') { |f| f.write text }
    FileUtils.mv path, backup_path
    FileUtils.mv new_path, path
  end
end

namespace :eyc do
  task :ssh, :roles => :app_master do
    replacement = []
    environment_name = ''
    eyc_proxy.app.each_with_index do |instance, index|
      environment_name = instance.environment[:name]
      replacement << %{
Host #{environment_name}#{index}
  Hostname #{instance.dns_name}
  User #{instance.users.first[:username]}
  StrictHostKeyChecking no
}
      end
    replacement = replacement.join
    r = StringReplacer.new File.expand_path("~/.ssh/config")
    r.replace! replacement, environment_name
  end
end
