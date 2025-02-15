(lem-lsp-server/defpackage:defpackage :lem-lsp-server/test/initialized
  (:use :cl
        :testif
        :lem-lsp-server/server
        :lem-lsp-server/test/test-server)
  (:local-nicknames (:protocol :lem-lsp-utils/protocol)
                    (:json :lem-lsp-utils/json)))
(in-package :lem-lsp-server/test/initialized)

(test did-not-initialized
  (let ((server (make-instance 'test-server)))
    (server-listen server)
    (let ((response
            (call-lsp-method server
                             "initialized"
                             nil)))
      (ok (equal -32002 (json:json-get response "code")))
      (ok (equal "did not initialize" (json:json-get response "message"))))))

(test success
  (let ((server (make-instance 'test-server)))
    (server-listen server)
    (lem-lsp-server/test/initialize:initialize-request server)
    (let ((response
            (call-lsp-method server
                             "initialized"
                             nil)))
      (ok (null response)))))
