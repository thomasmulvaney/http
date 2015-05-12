(ns http.server
  (:require [pixie.io.tcp :as tcp]
            [pixie.io     :as io]
            [pixie.string :as string]))

(defn line->kv
  [line]
  (let [[key & vals] (string/split line " ")
        val (string/join " " vals)]
    [(string/replace key ":" "") val]))

(defn http-parser
  [input-stream]
  (let [[head & lines] (io/line-seq input-stream)
        [method location protocol] (string/split head " ")
        base {:method method
              :protocol protocol
              :location location}
        options (->> lines
                     (remove string/blank?)
                     (map line->kv))]
    (reduce (fn [req [opt value]]
              (assoc-in req [:headers opt] value))
            base
            options)))

(defn kv->line
  [[k v]]
  (str k ": " v))

(defn header-map->lines
  [headers]
  (->> headers
       (map kv->line)
       (string/join "\r\n")))

(defn response
  [response-map]
  (let [{:keys [protocol status phrase headers body]} response-map]
    (assert (string? protocol))
    (assert (integer? status) "Status must be an integer")
    (assert (string? phrase))
    (let [response (str protocol " " status " " phrase)
          header-lines (header-map->lines headers)]
      (str response     "\r\n" 
           header-lines "\r\n\r\n" 
           body))))

(defn start
  "Starts a http server"
  [ip port handler]
  (tcp/tcp-server ip port 
                  (fn [tcp-stream]
                    (->> tcp-stream
                         http-parser
                         handler
                         response
                         (io/spit tcp-stream))
                    (dispose! tcp-stream))))
