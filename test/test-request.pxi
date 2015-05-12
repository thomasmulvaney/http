(ns test.test-request
  (:require [pixie.test :refer [deftest assert= assert-throws?]]
            [http.protocol :as protocol]
            [http.request :as request]))

;; For the sake of testing this is will mock our TCP stream.
;; Its an implementation of IStreamCursor which takes a stream rather
;; than a TCPStream
(deftype TestStreamCursor [string idx]
  protocol/IStreamCursor
  (protocol/-current [self]
    (int (nth string idx)))
  (protocol/-next! [self]
    (set-field! self :idx (inc idx))))

(defn test-stream-cursor
  [string]
  (->TestStreamCursor string -1))

(deftest test-parse-method
  (assert= :get     (request/method-parser (test-stream-cursor "GET ")))
  (assert= :post    (request/method-parser (test-stream-cursor "POST ")))
  (assert= :put     (request/method-parser (test-stream-cursor "PUT ")))
  (assert= :delete  (request/method-parser (test-stream-cursor "DELETE ")))
  (assert= :connect (request/method-parser (test-stream-cursor "CONNECT ")))

  (assert= :get     (request/method-parser (test-stream-cursor "GET junk")))
  (assert= :post    (request/method-parser (test-stream-cursor "POST junk")))
  (assert= :put     (request/method-parser (test-stream-cursor "PUT junk")))
  (assert= :delete  (request/method-parser (test-stream-cursor "DELETE junk")))
  (assert= :connect (request/method-parser (test-stream-cursor "CONNECT junk")))

  (assert-throws? (request/method-parser (test-stream-cursor "GET")))
  (assert-throws? (request/method-parser (test-stream-cursor "POST")))
  (assert-throws? (request/method-parser (test-stream-cursor "PUT")))
  (assert-throws? (request/method-parser (test-stream-cursor "DELETE")))
  (assert-throws? (request/method-parser (test-stream-cursor "CONNECT"))))

(deftest test-parse-url
  (assert= "/"    (request/url-parser (test-stream-cursor "/ HTTP/")))
  (assert= "/foo" (request/url-parser (test-stream-cursor "/foo HTTP/")))
  (assert= "/foo" (request/url-parser (test-stream-cursor "/foo HTTP/junk")))
  (assert= "/foo/123" (request/url-parser (test-stream-cursor "/foo/123 HTTP/")))
  (assert= "/foo/123?abc=1" (request/url-parser (test-stream-cursor "/foo/123?abc=1 HTTP/")))
  (assert-throws? (request/url-parser (test-stream-cursor "/ NOT_HTTP")))
  (assert-throws? (request/url-parser (test-stream-cursor "/HTTP/")))
  (assert-throws? (request/url-parser (test-stream-cursor "/foo NOT_HTTP/"))))

(deftest test-parse-major
  (assert= "1"  (request/major-parser (test-stream-cursor "1.1")))
  (assert= "1"  (request/major-parser (test-stream-cursor "1.234junk")))
  (assert= "42" (request/major-parser (test-stream-cursor "42.42junk")))
  (assert-throws? (request/major-parser (test-stream-cursor "42")))
  (assert-throws? (request/major-parser (test-stream-cursor "42junk"))))

(deftest test-parse-minor
  (assert= "1"   (request/minor-parser (test-stream-cursor "1\r\n")))
  (assert= "234" (request/minor-parser (test-stream-cursor "234\r\n")))
  (assert= "42"  (request/minor-parser (test-stream-cursor "42\r\n"))))

(deftest test-parse-header-type
  (assert= "foo" (request/header-type-parser (test-stream-cursor "foo: bar\r\n")))
  (assert= "Content-Type" (request/header-type-parser (test-stream-cursor "Content-Type: image/png\r\n")))
  (assert-throws? (request/header-type-parser (test-stream-cursor "Content-Type:image/png\r\n")))
  (assert-throws? (request/header-type-parser (test-stream-cursor "Content-Type image/png\r\n"))))

(deftest test-lazy-request-parser
  (let [new-req (fn [] (-> (str "GET /foo HTTP/1.1\r\n"
                                 "Content-Type: image/png\r\n"
                                 "User-Agent: Tester-McGee\r\n"
                                "\r\n")
                            (test-stream-cursor)
                           (request/lazy-request-parser)))]
    ;; Reading just the method will not read the url
    (let [req (new-req)]
      (assert= :get (protocol/-method req))
      (assert= nil (get-field req :url))
      (assert= nil (get-field req :major))
      (assert= nil (get-field req :minor))
      (assert= nil (get-field req :headers))
      )

    ;; Reading the url will read the method
    (let [req (new-req)]
      (assert= "/foo" (protocol/-url req))
      (assert= :get (get-field req :method))
      (assert= nil (get-field req :major))
      (assert= nil (get-field req :minor))
      (assert= nil (get-field req :headers)))
   
    ;; Reading the http major verison will read the method and url 
    (let [req (new-req)]
      (assert= "1" (protocol/-major req))
      (assert= :get (get-field req :method))
      (assert= "/foo" (get-field req :url))
      (assert= nil (get-field req :minor))
      (assert= nil (get-field req :headers)))

    ;; Reading the http minor verison will read the major, method and url 
    (let [req (new-req)]
      (assert= "1" (protocol/-minor req))
      (assert= :get (get-field req :method))
      (assert= "/foo" (get-field req :url))
      (assert= "1" (get-field req :major))
      (assert= nil (get-field req :headers)))

    ;; Reading the headers will read the minor, major, method and url 
    (let [req (new-req)]
      (assert= {"Content-Type" "image/png"
                "User-Agent" "Tester-McGee"} 
               (protocol/-headers req))
      (assert= :get (get-field req :method))
      (assert= "/foo" (get-field req :url))
      (assert= "1" (get-field req :major))
      (assert= "1" (get-field req :minor)))))
