{ pkgs }: { port ? "5432" }:
pkgs.writeText "postgreql.conf" ''
#datestyle = 'iso, mdy'
timezone = 'America/Chicago'
lc_messages = 'C'			# locale for system error message strings
lc_monetary = 'C'			# locale for monetary formatting
lc_numeric = 'C'			# locale for number formatting
lc_time = 'C'				# locale for time formatting

# default configuration for text search
listen_addresses = '*'		# what IP address(es) to listen on;
port = ${port}
max_connections = 100			# (change requires restart)
unix_socket_directories = '/tmp'	# comma-separated list of directories
shared_buffers = 128MB			# min 128kB
dynamic_shared_memory_type = posix	# the default is the first option
max_wal_size = 1GB
min_wal_size = 80MB

log_timezone = 'America/Chicago'
default_text_search_config = 'pg_catalog.english'

# TODO: figure out, wth this is
#shared_preload_libraries = 'auto_explain,pgsodium'
#pgsodium.getkey_script = '@PGSODIUM_GETKEY_SCRIPT@'
''
