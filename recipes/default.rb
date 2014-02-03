include_recipe 'role-base'
include_recipe 'balanced-omnibus'

%w(python-virtualenv python-dev build-essential libpq-dev cython ruby1.9.1 ruby1.9.1-dev iftop).each do |package_name|
  package package_name do
    action :install
  end
end

%w(fpm deb-s3 bundle).each do |name|
  gem_package name do
    action :install
  end
end

%w(depot).each do |name|
  python_pip name do
    action :upgrade
  end
end

file '/root/.ssh/ibs.pem' do
  owner 'root'
  group 'root'
  mode '600'
  content citadel['ibs/id_rsa.pem']
end

r = resources(:template => '/root/.ssh/config')
r.cookbook 'ibs'

git '/root/omnibus-balanced' do
  repository 'git@github.com:balanced/omnibus-balanced.git'
  reference 'master'
  action :checkout
  user 'root'
  group 'root'
end

file '/root/packages@vandelay.io.pem' do
  content citadel['jenkins_builder/packages@vandelay.io.pem']
  owner 'root'
  group 'root'
  mode '600'
end

execute 'gpg --import /root/packages@vandelay.io.pem' do
  user 'root'
  not_if 'env HOME=/root gpg --list-secret-keys 277E7787'
  environment 'HOME' => Dir.home('root') # Because GPG uses $HOME instead of real home
end

template "/root/.aws" do
  user 'root'
  group 'root'
  mode '600'
  source 'aws.erb'
  variables(
    :access_key_id => citadel['ibs/aws_access_key_id'].strip,
    :secret_access_key => citadel['ibs/aws_secret_access_key'].strip
  )
end

ruby_block 'include-aws' do
  block do
    file = Chef::Util::FileEdit.new('root/.bashrc')
    file.insert_line_if_no_match(
      "# include aws",
      "\n# include aws\nif [ -f ~/.aws ]; then . ~/.aws; fi"
    )
    file.write_file
  end
end
