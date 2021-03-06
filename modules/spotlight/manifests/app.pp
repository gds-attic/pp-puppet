class spotlight::app (
  $port       = undef,
  $workers    = 4,
  $app_module = undef,
  $user       = undef,
  $group      = undef,
) {
  include performanceplatform::nodejs
  include performanceplatform::checks::spotlight

  performanceplatform::app { 'spotlight':
    port                        => $port,
    workers                     => $workers,
    app_module                  => $app_module,
    user                        => $user,
    group                       => $group,
    servername                  => $::spotlight_vhost,
    proxy_ssl                   => true,
    ssl_cert                    => hiera('environment_ssl_cert'),
    ssl_key                     => hiera('environment_ssl_key'),
    extra_env                   => {
      'NODE_ENV' => $::pp_environment,
    },
    upstart_desc                => 'Spotlight job',
    upstart_exec                => 'node --trace-gc app/server.js',
    proxy_append_forwarded_host => false,
    request_uuid                => true,
  }

  nginx::resource::location { 'spotlight-app-assets':
    location            => '/assets/',
    location_custom_cfg => {
      'rewrite' => "^/assets/(.*)$ https://${::assets_vhost}/spotlight/\$1 permanent",
    },
    vhost               => $::spotlight_vhost,
  }

}
