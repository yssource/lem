(defpackage :lem.loading-spinner
  (:use :cl :lem :alexandria)
  (:export :start-loading-spinner
           :stop-loading-spinner)
  #+sbcl
  (:lock t))
(in-package :lem.loading-spinner)

(defconstant +loading-interval+ 80)

(define-attribute spinner-attribute
  (t :foreground "yellow"))

(defclass spinner ()
  ((frames :initform #("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
           :reader spinner-frames)
   (frame-index :initform 0
                :accessor spinner-frame-index)
   (timer :initarg :timer
          :reader spinner-timer)
   (loading-message :initarg :loading-message
                    :reader spinner-loading-message)))

(defvar *spinner-table* (make-hash-table))

(defun buffer-spinner (buffer)
  (buffer-value buffer 'spinner))

(defun (setf buffer-spinner) (spinner buffer)
  (setf (buffer-value buffer 'spinner) spinner))

(defmethod convert-modeline-element ((spinner spinner) window)
  (let ((attribute (merge-attribute (ensure-attribute 'modeline t)
                                    (ensure-attribute 'spinner-attribute))))
    (values (format nil
                    "~A ~A  "
                    (elt (spinner-frames spinner)
                         (spinner-frame-index spinner))
                    (or (spinner-loading-message spinner) ""))
            attribute
            :right)))

(defun update-spinner-frame (spinner)
  (setf (spinner-frame-index spinner)
        (mod (1+ (spinner-frame-index spinner))
             (length (spinner-frames spinner)))))

(defgeneric start-loading-spinner (type &key &allow-other-keys))
(defgeneric stop-loading-spinner (spinner))

(defclass modeline-spinner (spinner)
  ((buffer :initarg :buffer
           :reader modeline-spinner-buffer)))

(defmethod start-loading-spinner ((type (eql :modeline)) &key buffer loading-message)
  (check-type buffer buffer)
  (unless (buffer-spinner buffer)
    (let* ((spinner)
           (timer (start-timer +loading-interval+ t (lambda () (update-spinner-frame spinner)))))
      (setf spinner
            (make-instance 'modeline-spinner
                           :timer timer
                           :loading-message loading-message
                           :buffer buffer))
      (modeline-add-status-list spinner buffer)
      (setf (buffer-spinner buffer) spinner)
      spinner)))

(defmethod stop-loading-spinner ((spinner modeline-spinner))
  (let ((buffer (modeline-spinner-buffer spinner)))
    (modeline-remove-status-list spinner buffer)
    (stop-timer (spinner-timer spinner))
    (setf (buffer-spinner buffer) nil)))
