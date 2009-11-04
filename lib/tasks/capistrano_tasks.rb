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
