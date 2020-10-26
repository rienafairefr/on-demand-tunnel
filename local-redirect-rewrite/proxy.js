"use strict";

/*

Creates a HTTP proxy that rewrites Host: header to a predefined value
Useful when forwarding requests to Apache or Nginx virtual hosts

Usage:

    PORT_LISTEN=123 PORT_TARGET=456 HOST_TARGET=127.0.0.1 HOST_ORIGIN="tere.ee" node proxy.js

Where

  * PORT_LISTEN is the port the proxy should be listening for incoming requests
  * PORT_TARGET is the port the target server is listening for
  * HOST_TARGET is the hostname or IP where the target server is listening on
  * HOST_ORIGIN is the value that is set for the Host: header

*/

var http = require("http"),
    url = require("url");

var listenPort = process.env.PORT_LISTEN || 8080,
    targetPort = process.env.PORT_TARGET || 9000,
    targetHost = process.env.HOST_TARGET || "localhost",
    origin = process.env.HOST_ORIGIN || "origin";

var server = http.createServer(function(request, response){
    var options, proxyRequest, user;

    if (request.headers['host']) {
        request.headers['host'] = request.headers['host'].replace('.local-redirect.', '.local.');
    }
    request.headers['x-forwarded-for'] = request.headers['x-forwarded-for'] || request.connection.remoteAddress;

    options = url.parse("http://" + targetHost+(targetPort?":"+targetPort:"") + request.url);
    options.method = request.method;
    options.headers = request.headers;

    proxyRequest = http.request(options);

    proxyRequest.addListener("response", function (proxyResponse) {
        proxyResponse.pipe(response);
        response.writeHead(proxyResponse.statusCode, proxyResponse.headers);

        // Log requests to console
        console.log("%s [%s] \"%s %s\" %s",
            request.headers['x-forwarded-for'],
            new Date().toISOString().replace(/T/, " ").replace(/\.\d+Z/i, ""),
            request.method,
            request.url,
            proxyResponse.statusCode);
    });

    request.pipe(proxyRequest);
});

server.listen(listenPort, function(){
    console.log("Proxy listening on port %s", listenPort);
    console.log("Forwarding requests to http://%s as %s", targetHost+(targetPort?":"+targetPort:""), origin);
});
