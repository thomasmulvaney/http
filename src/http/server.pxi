(ns http.server
  (:require [pixie.io.tcp :as tcp]
            [pixie.io     :as io]
            [pixie.string :as string]
            [http.request :as request]
            [http.protocol :as protocol]))

(defn start
  "Starts a http server"
  [ip port handler]
  (tcp/tcp-server ip port 
                  (fn [tcp-stream]
                    (let [req (-> io/buffered-input-stream
                                  request/stream-cursor
                                  request/lazy-request-parser)]
                      (try
                        (println (protocol/-headers req))
                        (println (protocol/-url req))
                        (catch e
                          (println "Failed to parse request: " e))))
                    (dispose! tcp-stream))))
