# Part 2: Adding a proxy

Now we will enable ourselves to evolve the application architecture by
separating out the HTTP end-point that users connect to from the
application server that is serving content. To do this, we will use nginx
as a fast, lightweight proxy, and continue to use an Apache2/php instance
running WordPress to generate the dynamic content. For the moment, we
should not see a big change in performance, but this is an important step
to enabling us to scale our application by caching content, and
load-balancing compute-heavy work across multiple instances.

The main change we will make in `docker-compose.yml` is to add a new proxy
service which will download the latest nginx container, pass through host
port 80 to the container (and we remove this config from our wordpress
container). The top of our `services` section now looks like this:

```
services:
  proxy:
    restart: always
    image: nginx:latest
    networks: 
      - external_network
    ports:
      - 80:80
    volumes:
      - ./nginx/tmp:/var/run/nginx
      - ./nginx/conf.d:/etc/nginx/conf.d
    command: [ nginx-debug, '-g', 'daemon off;' ]
```

We now map a custom configuration for our WordPress install into the
`/etc/nginx/conf.d` directory of our container. This basic nginx configuration
specifies that we are the default server for all connections to port 80,
regardless of the requested domain name (this allows us to connect using just
the IP address), and that all requests should be passed to the wordpress
service:

```
server {
        listen 80 default_server;
        listen   [::]:80 default_server;

        server_name example.com;
        location / {
            proxy_pass http://wordpress;
        }
}
```

We also added a new database file to `mysql/initdb` which maps to the special
directory in the container `/docker-entrypoint-initdb.d` - if the database is
not already initialized, the database back-up in this directory will
automatically be loaded at start-up, as described in [the documentation of
the MySQL container](https://hub.docker.com/_/mysql).

When we start the application with a database dump, it takes a few seconds for
the database to become available. We can force the wordpress container to wait
for the database to be ready by adding a `depends_on` condition to the
WordPress container options. The `wordpress` container will wait until the
database container passes its health check before starting.

Before starting our application, we will need to update the IP addresses used
by WordPress as part of its configuration, and in the database dump of posts
and comments, to reflect the public IP address of your instance. 
```
cd ../mysql/initdb
sed -i 's/129\.213\.187\.155/YOUR_IP_ADDRESS/g' pi_day.sql
cd ../../wordpress2
```
This command replaces the IP address the author obtained while preparing the
tutorial with YOUR_IP_ADDRESS in `mysql/initdb/pi_day.sql`. You should replace
`YOUR_IP_ADDRESS` with the IP address for your instance.

After running `docker-compose up -d` with this file, we now have 3 containers
running, and the service should take about 20 seconds to start up, due to the
MySQL health check.

```
[opc@cloud-native-wordpress wordpress2]$ docker-compose up -d
[+] Running 4/4
 ⠿ Network wordpress2_external_network  Created                                                                  0.3s
 ⠿ Container wordpress2-db-1            Healthy                                                                 21.0s
 ⠿ Container wordpress2-proxy-1         Started                                                                  0.6s
 ⠿ Container wordpress2-wordpress-1     Started                                                                 21.3s
```

We can now see how queries are being handled by the server by checking the
container logs with `docker-compose logs -f` (the `-f` option allows us to
follow along in real-time) while we interact with the website.

When we send a request to the site, we first see that the message is
intercepted by `wordpress2-proxy-1` before being passed along to
`wordpress2-wordpress-1`, where the page request is satisfied and returned to
the requester.

```
wordpress2-wordpress-1  | 172.20.0.4 - - [24/Feb/2023:01:52:01 +0000] "GET / HTTP/1.0" 200 11352 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36"
wordpress2-proxy-1      | 173.76.40.122 - - [24/Feb/2023:01:52:01 +0000] "GET / HTTP/1.1" 200 10949 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36" "-"
wordpress2-proxy-1      | 173.76.40.122 - - [24/Feb/2023:01:52:02 +0000] "GET /2023/02/24/welcome-to-pi-day-2023/ HTTP/1.1" 200 14761 "http://129.213.187.155/" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36" "-"
wordpress2-wordpress-1  | 172.20.0.4 - - [24/Feb/2023:01:52:02 +0000] "GET /2023/02/24/welcome-to-pi-day-2023/ HTTP/1.0" 200 15359 "http://129.213.187.155/" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36"
```

Before proceeding: a word on creating database back-ups. To run commands in
the context of the container, we can use `docker-compose exec servicename <cmd>`.
To generate database back-ups for our WordPress instance, we run `mysqldump`
inside the container as the database root user - giving the database root
password we passed to the container at startup when prompted - and save the SQL
file generated to the local filesystem, with:

```
docker-compose exec db mysqldump -u root -p wordpress > pi_day.sql
```

When running a live service, you will want to do this every day in a cron job,
and save several days of back-ups, to ensure that you can restore the service
quickly in the event of unexpected data loss.

Now that we have a proxy, and the ability to reload our database after
completely changing the application architecture, we are ready to experiment
with load balancing! Let's move on to [part 3](../wordpress3).

