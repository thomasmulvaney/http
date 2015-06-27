(ns examples.simple
  (:require [http.server :as server]
            [http.protocol :as proto]
            [pixie.uv :as uv]))

(def requests (atom 0))

(def start (atom nil))

(defn handler [req]
  (println @requests)
  (if (= 299 @requests)
    (println "TIME: " (/ (- (uv/uv_hrtime) @start)
                         1000000.0 @requests)))
  (if (zero? @requests)
    (reset! start (uv/uv_hrtime)))
  (proto/-method req)
  (swap! requests inc))

(server/start "127.0.0.1" 5000 handler)
