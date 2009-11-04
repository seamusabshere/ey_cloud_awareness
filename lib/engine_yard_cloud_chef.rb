module EngineYardChef
  DNA_PATH = '/etc/chef/dna.json'
  # Load the Chef DNA file from /etc/chef/dna.json
  # >> JSON.load(IO.read('/etc/chef/dna.json')).keys   
  # => ["aws_secret_key", "db_slaves", "user_ssh_key", "admin_ssh_key", "backup_interval", "instance_role", "mailserver", "utility_instances", "crons", "backup_window", "removed_applications", "alert_email", "applications", "gems_to_install", "members", "reporting_url", "aws_secret_id", "environment", "users", "master_app_server", "db_host", "packages_to_install", "haproxy"]
  def self.dna
    @@dna ||= JSON.load(IO.read(DNA_PATH)).recursive_symbolize_keys!
  end
end
