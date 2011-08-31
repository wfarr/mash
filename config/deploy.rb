# this file ONLY used for bootstrapping - use knife to deploy changes

require 'capistrano/cowboy'
require 'yaml'

configuration = YAML.load_file('config/mash.yml')

set :user, configuration[:user]

server configuration[:server], :mash

task :bootstrap do
  dependencies.install
  ruby.install
  rubygems.install
  chef.install
  chef.bootstrap
  chef.configure_knife
end

namespace :dependencies do
  task :install do
    run [
      'sudo apt-get update || true',
      'sudo apt-get install -q -y build-essential zlib1g-dev libssl-dev libreadline5-dev wget git-core ssl-cert'
    ].join(' && ')
  end
end

namespace :ruby do
  task :install do
    run [
      'sudo apt-get remove -q -y ^.*ruby.* || true',
      'cd /tmp',
      'sudo rm -rf ruby-enterprise-1.8.7-2011.02* || true',
      'sudo mkdir -p /usr/lib/ruby/gems/1.8/gems || true',
      'wget -q http://rubyenterpriseedition.googlecode.com/files/ruby-enterprise-1.8.7-2011.03.tar.gz',
      'tar xzf ruby-enterprise-1.8.7-2011.03.tar.gz',
      'sudo /tmp/ruby-enterprise-1.8.7-2011.03/installer --dont-install-useful-gems --no-dev-docs -a /usr',
    ].join(' && ')
  end
end

namespace :rubygems do
  task :install do
    run [
      'cd /tmp',
      'sudo rm -rf rubygems-1.8.7 || true',
      'wget -q http://production.cf.rubygems.org/rubygems/rubygems-1.8.7.tgz',
      'tar xfz rubygems-1.8.7.tgz',
      'cd /tmp/rubygems-1.8.7',
      'sudo ruby setup.rb',
      'sudo ln -s /usr/bin/gem1.8 /usr/bin/gem || true',
    ].join(' && ')
  end
end

namespace :chef do
  task :install do
    sudo 'gem install chef ohai --no-ri --no-rdoc'
  end

  task :bootstrap do
    run 'mkdir -p /tmp/chef-solo'
    solo_rb = <<-EOF
file_cache_path "/tmp/chef-solo"
cookbook_path "/tmp/chef-solo/cookbooks"
EOF
    put solo_rb, "/home/#{configuration[:user]}/solo.rb"
    sudo 'mkdir -p /etc/chef'
    run 'sudo mv ~/solo.rb /etc/chef/solo.rb'
    chef_json = <<-EOF
{
  "chef_server": {
    "server_url": "http://#{configuration[:server]}:4000",
    "webui_enabled": true
  },
  "run_list": [ "recipe[chef-server::rubygems-install]" ]
}
    EOF
    put chef_json, "/home/#{configuration[:user]}/chef.json"
    sudo 'chef-solo -c /etc/chef/solo.rb -j ~/chef.json -r http://s3.amazonaws.com/chef-solo/bootstrap-latest.tar.gz'
    run 'mkdir -p ~/.chef'
    sudo 'cp /etc/chef/validation.pem /etc/chef/webui.pem ~/.chef'
    sudo "chown -R #{configuration[:user]} ~/.chef"
  end
  
  task :configure_knife do
    knife_configuration = <<-EOF
log_level                :info
log_location             STDOUT
node_name                '#{configuration[:user]}'
client_key               '/home/#{configuration[:user]}/#{configuration[:user]}.pem'
validation_client_name   'chef-validator'
validation_key           '.chef/validation.pem'
chef_server_url          'http://#{configuration[:server]}:4000'
cache_type               'BasicFile'
cache_options( :path => '/home/#{configuration[:user]}/checksums' )
EOF
    put knife_configuration, "/home/#{configuration[:user]}/.chef/knife.rb"
    run "knife client create #{ENV['USER']} -n -a -f /tmp/#{ENV['USER']}.pem"
    Dir.mkdir(".chef") unless File.directory?('.chef')
    download "/tmp/#{ENV['USER']}.pem", ".chef/#{ENV['USER']}.pem"
    download "/home/#{configuration[:user]}/.chef/validation.pem", ".chef/chef-validator.pem"
    f = File.open('.chef/knife.rb', 'w+')
    f.write(<<-EOF
current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                "#{ENV['USER']}"
client_key               "\#{current_dir}/#{ENV['USER']}.pem"
validation_client_name   "chef-validator"
validation_key           "\#{current_dir}/chef-validator.pem"
chef_server_url          "http://#{configuration[:server]}:4000"
cache_type               'BasicFile'
cache_options( :path => "\#{ENV['HOME']}/.chef/checksums" )
cookbook_path            ["\#{current_dir}/../cookbooks"]
EOF
    )
    f.close
    puts <<-EOF

A knife.rb, private key, and the chef validator key are all in the .chef directory.

Copy .chef to the project of your choice and run `knife client list`. Enjoy!

EOF
  end
end
