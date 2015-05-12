HTTP
========

A basic http server for pixie.

Usage
=====

```clojure
(ns skynet.core
  (:require [http.server :as server]))

(defn my-handler [req]
  (println "Received a request")
  {:status 200
   :phrase "OK"
   :protocol "HTTP/1.1"
   :body (str "<h1>You are visiting " (req :location) "</h1>")})
   
(server/start "127.0.0.1" 4000 my-handler) 
```

A handler is a function which accepts a request map and returns a response
map.

The request map contains `:location`, `:method`, `:protocol` and `:headers` keys. The `:headers` key contains a map of HTTP headers. The response map must have `:status`, `:phrase` and `:protocol` keys set. `:body` should be a string.
