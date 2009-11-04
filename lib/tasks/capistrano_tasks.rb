require 'ey_cloud_awareness'

namespace :eyc do
  task :setup, :roles => :app_master do
    upload File.expand_path(File.join(File.dirname(__FILE__), 'ey_cloud_awareness.rake')), "#{deploy_to}/current/lib/tasks"
  end
end
