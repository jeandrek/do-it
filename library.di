;;;; Do-it library

(defmacro inc (var)
  `(set ,var (+ ,var 1)))

(defmacro for (init test step . body)
  `(block
     ,init
     (while ,test
       ,@body
       ,step)))
