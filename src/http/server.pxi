(ns http.server
  (:require [pixie.io.tcp :as tcp]
            [pixie.io     :as io]
            [pixie.string :as string]
            [pixie.time :refer [time]]
            [http.request :as request]
            [http.protocol :as protocol]))

(defn start
  "Starts a http server"
  [ip port handler]
  (tcp/tcp-server ip port 
                  (fn [tcp-stream]
                    (let [req (-> tcp-stream
                                  io/buffered-input-stream
                                  request/stream-cursor
                                  request/lazy-request-parser)]
                      (handler req))
                    (dispose! tcp-stream))))
