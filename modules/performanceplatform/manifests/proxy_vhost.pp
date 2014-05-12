define performanceplatform::proxy_vhost(
  $port                = '80',
  $priority            = '10',
  $template            = 'nginx/vhost-proxy.conf.erb',
  $upstream_server     = 'localhost',
  $upstream_port       = '8080',
  $servername          = '',
  $serveraliases       = undef,
  $ssl                 = false,
  $ssl_port            = '443',
  $ssl_path            = hiera('ssl::params::ssl_path'),
  $ssl_cert            = hiera('ssl::params::ssl_cert_file'),
  $ssl_key             = hiera('ssl::params::ssl_key_file'),
  $ssl_redirect        = false,
  $isdefaultvhost      = false,
  $proxy               = true,
  $proxy_append_forwarded_host = false,
  $proxy_set_forwarded_host = false,
  $forward_host_header = true,
  $client_max_body_size = '10m',
  $five_critical        = '~:0',
  $five_warning         = '~:0',
  $four_critical        = '~:0',
  $four_warning         = '~:0',
  $sensu_check          = true,
  $pp_only_vhost        = false,
  $denied_http_verbs    = [],
  $auth_basic           = undef,
  $auth_basic_user_file = undef,
  $block_all_robots     = true,
) {

  $graphite_servername = regsubst($servername, '\.', '_', 'G')

  if $sensu_check {
    performanceplatform::checks::graphite { "5xx_rate_${servername}":
      # Total number of 5xx requests over the last minute
      target            => "hitcount(transformNull(stats.nginx.${::hostname}.${graphite_servername}.http_5*,0),'1min')",
      warning           => $five_warning,
      critical          => $five_critical,
      interval          => 60,
      ignore_no_data    => true,
      ignore_http_error => true,
      handlers          => ['default'],
    }

    performanceplatform::checks::graphite { "4xx_rate_${servername}":
      # Total number of 4xx requests over the last minute
      target            => "hitcount(transformNull(stats.nginx.${::hostname}.${graphite_servername}.http_4*,0),'1min')",
      warning           => $four_warning,
      critical          => $four_critical,
      interval          => 60,
      ignore_no_data    => true,
      ignore_http_error => true,
      handlers          => ['default'],
    }
  } else {
    sensu::check { "5xx_rate_${servername}":
      command => "",
    }
    sensu::check { "4xx_rate_${servername}":
      command => "",
    }
  }

  # Restrict access beyond GDS ips
  if $pp_only_vhost {
    $gds_only = hiera('pp_only_vhost')
    $magic_with_pp_only = "${magic}${gds_only}"
  } else {
    $magic_with_pp_only = $magic
  }

  logrotate::rule { "${title}-json-logs":
    path         => "/var/log/nginx/${servername}.*.log.json",
    rotate       => 30,
    rotate_every => 'day',
    missingok    => true,
    compress     => true,
    create       => true,
    create_mode  => '0640',
    create_owner => $::user,
    create_group => $::group,
    postrotate   => '[ ! -f /var/run/nginx.pid ] || kill -USR1 `cat /var/run/nginx.pid`',
  }

  $upstream_name = "${name}-upstream"

  nginx::resource::upstream { $upstream_name:
    members => [
      "${upstream_server}:${upstream_port}",
    ]
  }

  $listen_options = $isdefaultvhost ? {
    true    => 'default',
    default => undef,
  }

  if $proxy_append_forwarded_host {
    $forwarded_host = [
      'X-Forwarded-Server  "$http_x_forwarded_server,$host"',
      'X-Forwarded-Host  "$http_x_forwarded_host,$host"',
    ]
  } elsif $proxy_set_forwarded_host {
    $forwarded_host = [
      'X-Forwarded-Server  "$http_x_forwarded_server"',
      'X-Forwarded-Host  "$http_x_forwarded_host"',
    ]
  } else {
    $forwarded_host = [
      'X-Forwarded-Server $host',
      'X-Forwarded-Host  $host',
    ]
  }

  if $forward_host_header {
    $forward_host = [
      'Host $host',
    ]
  } else {
    $forward_host = []
  }
  $forwarded_proto = [
    'X-Forwarded-Proto  $scheme',
  ]

  if $denied_http_verbs and !empty($denied_http_verbs) {
    $vhost_cfg_append = {
      '' => inline_template('if ( $request_method ~ \'^(?:<%= @denied_http_verbs.join(\'|\') -%>)$\' ) { return 403; } #'),
    }
  } else {
    $vhost_cfg_append = undef
  }

  nginx::resource::vhost { $servername:
    listen_port => $port,
    listen_options => $listen_options,
    proxy => "http://${upstream_name}",
    ssl                         => $ssl,
    ssl_port                    => $ssl_port,
    ssl_cert                    => "${ssl_path}/${ssl_cert}",
    ssl_key                     => "${ssl_path}/${ssl_key}",
    rewrite_to_https            => $ssl_redirect,
    client_max_body_size        => $client_max_body_size,
    proxy_set_header            => flatten([$forwarded_host, $forward_host, $forwarded_proto]),
    access_log                  => "/var/log/nginx/${servername}.access.log.json json_event",
    error_log                   => "/var/log/nginx/${servername}.error.log",
    auth_basic                  => $auth_basic,
    auth_basic_user_file        => $auth_basic_user_file,
    vhost_cfg_append => $vhost_cfg_append,
  }

  if $block_all_robots {
    nginx::resource::location { "${servername}-robots":
      vhost               => $servername,
      location            => '/robots.txt',
      ssl                 => $ssl,
      location_custom_cfg => {
        'return' => '200 "User-agent: *\nDisallow: /"',
      },
    }
  }

}
