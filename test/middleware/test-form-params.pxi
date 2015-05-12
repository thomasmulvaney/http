(ns test.middleware.test-form-params
  (:require [pixie.test :refer [deftest assert= assert-throws?]]
            [http.parse :as parse]
            [http.middleware.form-params :as form-params]))

#_(deftest has-form-params?
  (assert= true 
           (form-params/has-form-params?
             (parse/request-message
               (str "POST / HTTP/1.1\r\n"
                    "Content-Type: application/x-www-form-urlencoded\r\n"))))
  (assert= false 
           (form-params/has-form-params?
             (parse/request-message
               (str "POST / HTTP/1.1\r\n"
                    "Content-Type: image/png\r\n")))))

#_(deftest add-form-params-to-req-map
  (assert= {:method   :post
            :protocol "HTTP/1.1"
            :uri      "/"
            :headers {"Content-Type" "application/x-www-form-urlencoded"}
            :body  "name=Bob&age=25"
            :form-params {"name" "Bob" "age" "25"}}
           (form-params/form-params
             (parse/request-message
               (str "POST / HTTP/1.1\r\n"
                    "Content-Type: application/x-www-form-urlencoded\r\n"
                    "\r\n"
                    "name=Bob&age=25")))))
