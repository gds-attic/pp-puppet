class pp_postgres::secondary {
  include("pp_postgres::server")

  $data_dir = "/var/lib/postgresql/9.1/main"
  $primary_host = "postgresql-primary"

  file { "${data_dir}/recovery.conf":
    ensure  => present,
    content => "standby_mode = 'on'\nprimary_conninfo = 'host=postgresql-primary-1 user=replicator'",
    owner   => "postgres",
    group   => "postgres",
  }
  file { '/usr/local/bin/start_replication.sh':
    ensure  => present,
    content => template("pp_postgres/start_replication.sh.erb"),
    mode    => '0555',
  }

  postgresql::server::config_entry { 'hot_standby':
    value => 'on',
  }
  postgresql::server::pg_hba_rule { 'stagecraft':
    type        => 'host',
    database    => 'stagecraft',
    user        => 'stagecraft',
    auth_method => 'md5',
    address     => '172.27.1.1/24',
  }
}
