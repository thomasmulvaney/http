(ns examples.simple
  (:require [http.server :as server]))

(defn handler [req]
  {:status 200
   :protocol "HTTP/1.1"
   :phrase "OK"
   :body (str "<h1>You are visiting page " (:location req) "</h1>")})

(server/start "127.0.0.1" 4000 handler)
