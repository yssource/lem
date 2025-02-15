(in-package :lem-base)

(define-editor-variable before-syntax-scan-hook nil)
(define-editor-variable after-syntax-scan-hook nil)
(define-editor-variable enable-syntax-highlight nil)

(defparameter *global-syntax-highlight* t)

(defun enable-syntax-highlight-p (buffer)
  (and *global-syntax-highlight*
       (variable-value 'enable-syntax-highlight :buffer buffer)))

(defun current-syntax-parser ()
  (syntax-table-parser (current-syntax)))

(defclass syntax-parser ()
  ())

(defgeneric %syntax-scan-region (parser start end))

(defvar *recursive-syntax-scan* nil)

(defun syntax-scan-region (start end)
  (assert (eq (point-buffer start)
              (point-buffer end)))
  (unless *recursive-syntax-scan*
    (let ((*recursive-syntax-scan* t))
      (run-hooks (make-per-buffer-hook :var 'before-syntax-scan-hook :buffer start)
                 start end)
      (without-interrupts
        (let ((buffer (point-buffer start)))
          (when (and (enable-syntax-highlight-p buffer)
                     (buffer-syntax-table buffer)
                     (syntax-table-parser (buffer-syntax-table buffer)))
            (let ((*current-syntax*
                    (buffer-syntax-table buffer)))
              (with-point ((start start)
                           (end end))
                (line-start start)
                (line-end end)
                (%syntax-scan-region (syntax-table-parser *current-syntax*) start end))))))
      (run-hooks (make-per-buffer-hook :var 'after-syntax-scan-hook :buffer start)
                 start end))))
