
class performanceplatform::monitoring (
) {

  file { '/etc/apache2/run':
    ensure  => link,
    target  => '/var/run/apache2',
    require => Package[$::graphite::params::apache_pkg],
    notify  => Service['apache2'],
  }

  file { '/etc/nginx/htpasswd':
    ensure    => present,
    content   => 'betademo:cBxAp7qb7cNXc', # nottobes
    subscribe => Service['nginx'],
  }

  class { 'sensu':
    dashboard_port     => 8090,
    dashboard_user     => 'betademo',
    dashboard_password => 'nottobes',
    rabbitmq_host      => 'rabbitmq',
    rabbitmq_password  => $::rabbitmq_sensu_password,
    rabbitmq_port      => 5672,
    server             => true,
    safe_mode          => true,
    require            => [ Class['redis'], Class['rabbitmq'] ],
  }

  rabbitmq_user { 'sensu':
    ensure   => present,
    password => $::rabbitmq_sensu_password,
    admin    => false
  }

  logstash::input::lumberjack { 'lumberjack-nginx':
    format          => 'json',
    type            => 'lumberjack',
    port            => 3456,
    ssl_certificate => 'puppet:///modules/performanceplatform/logstash.pub',
    ssl_key         => 'puppet:///modules/performanceplatform/logstash.key',
  }

  logstash::filter::grep { 'tag-lumberjack':
    type    => 'lumberjack',
    add_tag => [ "%{tag}" ],
  }

  logstash::filter::mutate { 'nginx-token-fix':
    type => 'lumberjack',
    tags => [ 'nginx' ],
    gsub => [
      '@source_host', '\.', '_',
      'server_name',  '\.', '_',
    ],
  }

  logstash::output::statsd { 'statsd':
    type      => 'lumberjack',
    tags      => [ 'nginx' ],
    count     => { '%{server_name}.http_%{status}' => 1 },
    timing    => {
      '%{server_name}.request_time' => '%{request_time}'
    },
    namespace => 'nginx',
  }

}
