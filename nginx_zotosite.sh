#!/bin/bash

NGINX_ROOT="/usr/local/nginx"

NGINX_AVAILABLE="${NGINX_ROOT}/conf/sites-available"
NGINX_ENABLED="${NGINX_ROOT}/conf/sites-enabled"

site=$2
site_config="${NGINX_AVAILABLE}/${site}.conf"
site_link="${NGINX_ENABLED}/${site}.conf"


function check_directory {
	dir="$1"

	if [ -e "$dir" ]; then
		if [ ! -d "$dir" ]; then
			echo "[FAIL] (${dir} exists and is not a directory)"
			exit 1
		fi
	else
		mkdir -p "$dir" &>/dev/null

		if [ $? = "1" ]; then
			echo "[FAIL] (unable to create ${dir})"
			exit 1
		fi
	fi
}

function create {
	echo -n "Generating site config ... "

	if [ -e "$site_config" ]; then
		echo "[FAIL] (already exists)"
		exit 1
	fi

	check_directory "$NGINX_AVAILABLE"

	cat << EOF > "${site_config}" 2>/dev/null
server {
        listen 80;
        server_name  ${site};

        access_log  logs/${site}.access.log;
        error_log  logs/${site}.error.log;

        keepalive_timeout 65;
        gzip off;

        location / {
            proxy_pass http://zotonic;
            proxy_redirect off;
            
            proxy_set_header   Host             \$host;
            proxy_set_header   X-Real-IP        \$remote_addr;
            proxy_set_header   X-Forwarded-For  \$proxy_add_x_forwarded_for;

            client_max_body_size       50m;
            client_body_buffer_size    128k;

            proxy_connect_timeout      90;
            proxy_send_timeout         90;
            proxy_read_timeout         90;

            proxy_buffer_size          4k;
            proxy_buffers              4 32k;
            proxy_busy_buffers_size    64k;
            proxy_temp_file_write_size 64k;
        }

        location /close-connection {
             keepalive_timeout 0;
             empty_gif;
        }
}
EOF

	if [ $? = "1" ]; then
		echo "[FAIL]"
		exit 1
	else
		echo "[DONE]"
	fi

	enable
}

function enable {
	echo -n "Enabling $site ... "

	check_directory "$NGINX_ENABLED"

	if [ -L "$site_link" ]; then
		echo "[DONE]"
		exit 0
	fi
	
	if [ ! -f "$site_config" ]; then
		echo "[FAIL] (site does not exist)"
		exit 1
	fi

	ln -s "$site_config" "$site_link" &>/dev/null

	if [ $? = "1" ]; then
		echo "[FAIL] (unable to symlink)"
		exit 1
	fi

	/etc/init.d/nginx reload 1>/dev/null

	if [ $? = "1" ]; then
		echo "[FAIL] (Nginx reload)"
		exit 1
	else
		echo "[DONE]"
		exit 0
	fi
}

function disable {
	echo -n "Disabling $site ... "

	if [ ! -L "$site_link" ]; then
		echo "[DONE]"
		exit 0
	fi

	rm "$site_link" &>/dev/null

	if [ $? = "1" ]; then
		echo "[FAIL] (unable to unlink)"
		exit 1
	fi

	/etc/init.d/nginx reload 1>/dev/null

	if [ $? = "1" ]; then
		echo "[FAIL] (Nginx reload)"
		exit 1
	else
		echo "[DONE]"
		exit 0
	fi
}


case $1 in
	create | enable | disable )
		$1
		;;
	* )
		echo "Usage: $0 {create|enable|disable} <site>"
		exit 1
		;;
esac
