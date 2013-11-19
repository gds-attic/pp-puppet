# Everything in this node definition depends on Hiera

# This defines the role of the node
if empty($machine_role) {
    $machine_role   = regsubst($::hostname, '^(.*)-\d$', '\1')
}

# Nginx Vhosts for later use
$domain_name         = hiera('domain_name')
$public_domain_name  = hiera('public_domain_name', $domain_name)
$admin_vhost         = join(['admin',$public_domain_name],'.')
$deploy_vhost        = join(['deploy',$domain_name],'.')
$elasticsearch_vhost = join(['elasticsearch', $domain_name], '.')
$kibana_vhost        = join(['kibana', $domain_name], '.')
$graphite_vhost      = join(['graphite',$domain_name],'.')
$logstash_vhost      = join(['logstash',$domain_name],'.')
$logging_vhost       = join(['logging',$domain_name],'.')
$alerts_vhost        = join(['alerts',$domain_name],'.')
$www_vhost           = join(['www',$public_domain_name],'.')
$spotlight_vhost     = join(['spotlight',$public_domain_name],'.')

$rabbitmq_sensu_password = hiera('rabbitmq_sensu_password')

$pp_environment = hiera('pp_environment')

# Classes
hiera_include('classes')

node default {
  # Create user accounts
  create_resources( 'account', hiera_hash('accounts') )

  # Install packages
  $system_packages = hiera_array( 'system_packages', [] )
  if !empty($system_packages) {
    package { $system_packages: ensure => installed }
  }

  # Firewall rules
  create_resources( 'ufw::allow', hiera_hash('ufw_rules') )

  # Create nginx proxies
  $vhost_proxies = hiera_hash( 'vhost_proxies', {} )
  if !empty($vhost_proxies) {
    create_resources( 'performanceplatform::proxy_vhost', $vhost_proxies )
  }

  # Create extra nginx conf
  $nginx_conf = hiera_hash( 'nginx_conf', {} )
  if !empty($nginx_conf) {
    create_resources( 'nginx::conf', $nginx_conf )
  }

  # Install the Backdrop apps
  $backdrop_apps = hiera_hash( 'backdrop_apps', {} )
  if !empty($backdrop_apps) {
    create_resources( 'backdrop::app', $backdrop_apps )
  }

  # Collect some metrics
  $collectd_plugins = hiera_array( 'collectd_plugins', [] )
  if !empty($collectd_plugins) {
    collectd::plugin { $collectd_plugins: }
  }

  $lumberjack_instances = hiera_hash( 'lumberjack_instances', {} )
  if !empty($lumberjack_instances) {
    create_resources( 'lumberjack::logshipper', $lumberjack_instances )
  }
}
