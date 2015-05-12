(ns http.request
  (:require [http.protocol :as protocol]
            [pixie.io :as io]
            [pixie.streams :as stream]
            [pixie.string :as string]))

(deftype StreamCursor [stream current]
  protocol/IStreamCursor
  (protocol/-current [self]
    current)
  (protocol/-next! [self]
    (set-field! self :current (io/read-byte stream))))

(defn stream-cursor 
  [stream]
  (->StreamCursor stream nil))

(def methods
  {"GET"     :get
   "POST"    :post
   "PUT"     :put
   "DELETE"  :delete
   "CONNECT" :connect
   "HEAD"    :head})

(defn method-substring?
  [s]
  (some #(string/starts-with? % s)
        (keys methods)))

(defn method-parser 
  [stream-cursor]
  (loop [acc []]
    (protocol/-next! stream-cursor)
    (if-not (method-substring? (apply str acc))
      (throw [::method-parser "Couldn't parse"]) 
      (if-let [method (methods (apply str acc))]
        (if (= \space (char (protocol/-current stream-cursor)))
          method
          (throw [::method-parser "Method should be followed by a space"]))
        (let [ch-int (protocol/-current stream-cursor)
              ch (char ch-int)]
          (recur (conj acc ch)))))))

(defn url-parser 
  [stream-cursor]
  (loop [acc []]
    (protocol/-next! stream-cursor)
    (let [ch-int (protocol/-current stream-cursor)
          ch (char ch-int)]
      (if (= \space ch)
        (do
          (when-not (and (do 
                         (protocol/-next! stream-cursor)
                         (= \H (char (protocol/-current stream-cursor))))
                       (do
                         (protocol/-next! stream-cursor)
                         (= \T (char (protocol/-current stream-cursor))))
                       (do
                         (protocol/-next! stream-cursor)
                         (= \T (char (protocol/-current stream-cursor))))
                       (do
                         (protocol/-next! stream-cursor)
                         (= \P (char (protocol/-current stream-cursor))))
                       (do
                         (protocol/-next! stream-cursor)
                         (= \/ (char (protocol/-current stream-cursor)))))
            (throw [::url-parser "URL should be followed by HTTP"]))
        (apply str acc))
        (recur (conj acc ch))))))

;; major version ends with a '.' eg 1.1
(defn major-parser 
  [stream-cursor]
  (loop [acc []]
    (protocol/-next! stream-cursor)
    (let [ch-int (protocol/-current stream-cursor)
          ch (char ch-int)]
      (if (= \. ch)
        (apply str acc)
        (if-not ((set string/digits) ch)
          (throw [::major-parser "Couldn't parse"])
          (recur (conj acc ch)))))))

;; expect a number char followed by \return \newline
(defn minor-parser 
  [stream-cursor]
  (loop [acc []]
    (protocol/-next! stream-cursor)
    (let [ch-int (protocol/-current stream-cursor)
          ch (char ch-int)]
      (if-not ((set string/digits) ch)
        (if-not (and (= \return  ch)
                     (do
                       (protocol/-next! stream-cursor)
                       (= \newline (char (protocol/-current stream-cursor))))) 
          (throw [::minor-parser "Couldn't parse"])
          (apply str acc))
        (recur (conj acc ch))))))

(defn header-type-parser 
  [stream-cursor]
  (loop [acc []]
    (protocol/-next! stream-cursor)
    (let [ch-int (protocol/-current stream-cursor)
          ch (char ch-int)]
      (if-not (= \: ch)
        (if (and (= \return ch)
                 (do
                   (protocol/-next! stream-cursor)
                   (= \newline (char (protocol/-current stream-cursor))))) 
          (if (empty? acc)
            nil
            (throw [::header-type-parser "Couldn't parse header type"]))
          (recur (conj acc ch)))
        (do
          (protocol/-next! stream-cursor)
          (if-not (= \space (char (protocol/-current stream-cursor)))
            (throw [::header-type-parser "Couldn't parse header type"])
            (apply str acc)))))))

(defn header-value-parser 
  [stream-cursor]
  (loop [acc []]
    (protocol/-next! stream-cursor)
    (let [ch-int (protocol/-current stream-cursor)
          ch (char ch-int)]
      (if ((set (str string/lower string/upper string/digits string/punctuation)) ch)
        (recur (conj acc ch))
        (if-not (and 
                  (= \return ch)
                  (do
                    (protocol/-next! stream-cursor)
                    (= \newline (char (protocol/-current stream-cursor)))))
          (throw [::header-value-parser "Couldn't parse header value"])
          (apply str acc))))))

(deftype LazyRequestParser 
  [stream-cursor method url major minor headers headers-parsed? body]
  protocol/IRequest
  (protocol/-method [self]
    (or method 
        (do
          (set-field! self :method (method-parser stream-cursor))
          method)))
  
  (protocol/-url [self]
    (or url 
        (do 
          (protocol/-method self)
          (set-field! self :url (url-parser stream-cursor))
          url)))
  
  (protocol/-major [self]
    (or major 
        (do 
          (protocol/-url  self)
          (set-field! self :major (major-parser stream-cursor))
          major)))

  (protocol/-minor [self]
    (or minor 
        (do 
          (protocol/-major self)
          (set-field! self :minor (minor-parser stream-cursor))
          minor)))

  (protocol/-version [self]
    {:major (protocol/-major self)
     :minor (protocol/-minor self)})

  (protocol/-headers [self]
    (or headers 
        (do (protocol/-minor self)
            (let [headers (loop [headers {}]
                            (if-let [type (header-type-parser stream-cursor)]
                              (let [val (header-value-parser stream-cursor)] 
                                (recur (assoc headers type val)))
                              headers))]
              (set-field! self :headers headers)
              (set-field! self :headers-parsed? true)
              headers)))))

(defn lazy-request-parser
  [stream-cursor]
  (->LazyRequestParser stream-cursor
                       nil ;method 
                       nil ;url
                       nil ;major
                       nil ;minor
                       nil ;headers
                       nil ;headers-parsed?
                       nil ;body
                       ))

(defn parse-eagerly
  [stream-cursor]
  (try
    (let [method (method-parser stream)
          url    (url-parser stream)
          major  (major-parser stream)
          minor  (minor-parser stream)
          headers (loop [headers {}]
                    (if-let [type (header-type-parser stream-cursor)]
                      (let [val (header-value-parser stream-cursor)] 
                        (recur (assoc headers type val)))
                      headers))]
      {:method method
       :url url
       :major major
       :minor minor
       :headers headers})
    (catch e
      (stream/dispose! stream))))

(deftype EagerRequestParser 
  [parsed-map]
  protocol/IRequest
  (protocol/-method [self]
    (:method parsed-map))
  
  (protocol/-url [self]
    (:url parsed-map))
 
  (protocol/-major [self]
    (:major parsed-map))

  (protocol/-minor [self]
    (:minor parsed-map))

  (protocol/-version [self]
    {:minor (protocol/-minor self)
     :major (protocol/-major self)})

  (protocol/-headers [self]
    (:headers parsed-map)))

(defn eager-request-parser
  [stream-cursor]
  (->EagerRequestParser (parse-eagerly stream-cursor)))
