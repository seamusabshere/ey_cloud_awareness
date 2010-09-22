require 'ey_cloud_awareness'

task :eyc_setup, :roles => :app_master do
  # pull JSON-encoded metadata
  output = capture('ey_cloud_awareness').gsub /\s+/, ' '
  if /(\{.*\})/.match(output)
    json_str = $1
    begin
      set :eyc_proxy, EngineYardCloudInstance.from_json(json_str)
    rescue
      $stderr.puts "[EY CLOUD AWARENESS GEM] Couldn't parse JSON, so just dumping what we got"
      $stderr.puts json_str
      raise $!
    end
  else
    $stderr.puts "[EY CLOUD AWARENESS GEM] Didn't get JSON we recognized back, just dumping what we got"
    $stderr.puts output
    raise
  end
  
  # now set up roles
  # role :app_master is already set
  role :db_master, eyc_proxy.db_master.dns_name
  eyc_proxy.app_servers.each do |i|
    role :app, i.dns_name
    role :web, i.dns_name
  end
  eyc_proxy.db_servers.each do |i|
    role :db, i.dns_name
  end
  eyc_proxy.utilities.each do |i|
    role :util, i.dns_name
  end
end

namespace :eyc do
  %w{ app_servers db_servers utilities all }.each do |name|
    task name, :roles => :app_master do
      require 'pp'
      pp eyc_proxy.send(name).map(&:to_hash)
    end
  end

  task :ssh, :roles => :app_master do
    require 'string_replacer'
    replacement = []
    counters = Hash.new(0)
    eyc_proxy.with_roles.each do |instance|
      case instance.role
      when 'db_master'
        explanation = ''
        shorthand = 'db_master'
      when 'app_master'
        explanation = ''
        shorthand = 'app_master'
      when 'solo'
        explanation = ''
        shorthand = 'solo'
      else
        explanation = " (#{counters[instance.role]})"
        shorthand = "#{instance.role}#{counters[instance.role]}"
        counters[instance.role] += 1
      end
      replacement << %{
  # #{instance.role}#{explanation}
  Host #{eyc_proxy.environment['name']}-#{shorthand}
    Hostname #{instance.dns_name}
    User #{instance.user['username']}
    StrictHostKeyChecking no
}
    end
    string = replacement.join
    ssh_config_path = File.expand_path("~/.ssh/config")
    r = StringReplacer.new ssh_config_path
    r.replace! string, eyc_proxy.environment['name'], nil
    
    $stderr.puts "[EY CLOUD AWARENESS GEM] Added this to #{ssh_config_path}"
    $stderr.puts string
  end
end
