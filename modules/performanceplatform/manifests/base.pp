# Base resources for all PP machines
class performanceplatform::base {
    stage { 'system':
        before => Stage['main'],
    }

    class { [ 'performanceplatform::dns',
              'performanceplatform::hosts' ]:
        stage => system,
    }

    class {'gstatsd': require => Class['python::install'] }

    # TODO: Copy required packages into our own PPA and remove the GOV.UK PPA
    # from this repo
    apt::ppa { 'ppa:gds/govuk': }
    apt::ppa { 'ppa:gds/performance-platform': }

    exec { 'apt-get-update':
        command => '/usr/bin/apt-get update || true',
        require => [Apt::Ppa['ppa:gds/govuk'], Apt::Ppa['ppa:gds/performance-platform']],
    }
    $machine_role = regsubst($::hostname, '^(.*)-\d$', '\1')

    file { '/etc/environment':
        ensure  => present,
        content => "PATH=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"
FACTER_machine_role=${machine_role}
"
    }
    file {'/etc/gds':
        ensure => directory,
    }
    # Make sure we are in UTC
    file { '/etc/localtime':
        source => '/usr/share/zoneinfo/UTC'
    }
    file { '/etc/timezone':
        content => 'UTC'
    }
    group { 'gds': ensure => present }
    file { '/etc/sudoers.d/gds':
        ensure  => present,
        mode    => '0440',
        content => '%gds ALL=(ALL) NOPASSWD: ALL
'
    }
    file { '/bin/su':
        ensure => present,
        mode   => '4750',
        owner  => 'root',
        group  => 'gds',
    }

    package { 'ruby1.9.1-dev':
        ensure => present,
    }

    package {'sensu-plugin':
      ensure   => installed,
      before   => Class['sensu'],
      provider => gem,
      require  => Package['ruby1.9.1-dev'],
    }

    vcsrepo { '/etc/sensu/community-plugins':
        ensure   => present,
        provider => git,
        source   => 'https://github.com/alphagov/sensu-community-plugins.git',
        revision => '99bbd0feeba1b84737e1f067448831317ae02c83',
    }

}
