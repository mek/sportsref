FROM httpd:2.4
ENTRYPOINT ["/usr/local/apache2/bin/apachectl", "-D", "FOREGROUND", "-D", "HTTP_PORT=8888"]
