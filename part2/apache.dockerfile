FROM httpd:2.4
ENTRYPOINT ["/usr/local/apache2/bin/httpd", "-D", "FOREGROUND"]
