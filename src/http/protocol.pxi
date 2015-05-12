(ns http.protocol)

(defprotocol IStreamCursor
  (-current [self])
  (-next!   [self]))

(defprotocol IRequest
  (-method  [self])
  (-url     [self])
  (-major   [self])
  (-minor   [self])
  (-version [self])
  (-headers [self])
  (-body    [self]))
