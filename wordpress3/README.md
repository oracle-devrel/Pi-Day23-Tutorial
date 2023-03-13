# Part 3: Using nginx as a load balancer

The next part of our journey will involve creating a load balancer
configuration in nginx, and using it to spread the incoming load to our
WordPress site across three identical WordPress instances serving the same
content. To do this, we create an `upstream` cluster in our nginx
configuration file. For this phase of the project, we will use the files
in the `wordpress3` folder of our repository (this directory).

First, we will modify `docker-compose.yml` to start three WordPress containers,
`wordpress1`, `wordpress2`, and (you guessed it) `wordpress3`. These containers
will have identical settings – in particular, all three will share the same
volume for the WordPress distribution files – this guarantees that all three
will have the same settings and plug-in setup. Our `docker-compose.yml` now
looks like this:

```
version: "3"

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

  wordpress1:
    restart: always
    image: wordpress:6.1-apache
    depends_on:
      db:
        condition: service_healthy
    environment:
      WORDPRESS_DB_HOST: 'db'
      WORDPRESS_DB_USER: 'wordpress'
      WORDPRESS_DB_PASSWORD: 'password1234'
      WORDPRESS_DB_NAME: 'wordpress'
    networks:
      - external_network
    volumes:
      - ./wordpress:/var/www/html

  wordpress2:
    exact copy of wordpress1

  wordpress3:
    exact copy of wordpress1

  db:
    unchanged
networks:
  external_network:
```

In `nginx/conf.d/wordpress.conf` we now use an upstream group to define the
services we will load balance across. The default load balancing method is
round-robin (1, 2, 3, 1, 2, 3, …), but there are [many options documented in
the nginx docs](https://docs.nginx.com/nginx/admin-guide/load-balancer/http-load-balancer/).
Among these: we can send requests to the node that has the least active
connections, or to a random node in the cluster. For session-aware
applications, we can always send requests from the same client to the same
server. We can also weight certain containers more or less (enabling, for
example, A-B testing using the load balancer). Incidentally, the nginx docs
mention a `http` directive which is unnecessary for us, as it is already
included by the configuration in the container - our `wordpress.conf` file
is being included by that configuration. Our nginx configuration now looks
like this:

```
upstream wpcluster {
        server wordpress1;
        server wordpress2;
        server wordpress3;
}

server {
        listen 80 default_server;
        listen   [::]:80 default_server;

        server_name example.com;
        location / {
            proxy_pass http://wpcluster;

        }
}
```

This time, when we start our service in `wordpress3`, we see five containers
starting. No container images are downloaded, since we are just starting three
copies of the same image for WordPress that we downloaded in the first step.

```
[opc@cloud-native-wordpress wordpress3]$ docker-compose up -d
[+] Running 6/6
 ⠿ Network wordpress3_external_network  Created                                                                  0.2s
 ⠿ Container wordpress3-proxy-1         Started                                                                  0.6s
 ⠿ Container wordpress3-db-1            Healthy                                                                 21.1s
 ⠿ Container wordpress3-wordpress3-1    Started                                                                 21.6s
 ⠿ Container wordpress3-wordpress1-1    Started                                                                 21.5s
 ⠿ Container wordpress3-wordpress2-1    Started                                                                 21.7s
```

If you run `docker-compose logs -f` now, you will see requests for resources
are being directed to all three WordPress nodes by the proxy service. As all
three share the same volume for WordPress files, and connect to the same
back-end database, from the user’s perspective, they are identical.

Now that we have our service load balancing, we should figure out how to do
less work, not more. That means enabling some caching.
[In our next step](../wordpress4), we will add a Redis object cache for
WordPress, and add a caching plug-in to WordPress to provide page caching.

