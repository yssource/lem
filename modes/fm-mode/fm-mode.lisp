(defpackage :lem-fm-mode
  (:use :cl :lem :lem.button))
(in-package :lem-fm-mode)

(defconstant +fm-max-number-of-frames+ 256)

(define-attribute fm-active-frame-name-attribute
  (t :foreground "black" :background "dark gray"))

(define-attribute fm-frame-name-attribute
  (t :foreground "dark gray" :background "gray"))

(define-attribute fm-background-attribute
  (t :underline-p t))

(defstruct %frame
  (id 0 :type integer)
  (frame nil :type lem::frame))

(defun %make-frame (id frame)
  (make-%frame :id id :frame frame))

(defclass vf (header-window)
  ((implementation
    :initarg :impl
    :initform nil
    :accessor vf-impl
    :type lem:implementation)
   (frames
    :initarg :frames
    :accessor vf-frames
    :type array)
   (current
    :initarg :current
    :accessor vf-current
    :type %frame)
   (display-width
    :initarg :width
    :accessor vf-width)
   (display-height
    :initarg :height
    :accessor vf-height)
   (changed
    :initform t
    :accessor vf-changed)
   (buffer
    :initarg :buffer
    :accessor vf-header-buffer)))

(defun make-vf (impl frame)
  (let* ((buffer (make-buffer "*fm*" :enable-undo-p nil :temporary t))
         (%frame (make-%frame :id 0 :frame frame))
         (frames (make-array +fm-max-number-of-frames+ :initial-element nil)))
    (setf (aref frames 0) %frame)
    (setf (lem:variable-value 'truncate-lines :buffer buffer) nil)
    (let ((vf (make-instance 'vf
                             :impl impl
                             :buffer buffer
                             :width (display-width)
                             :height (display-height)
                             :frames frames
                             :current %frame)))
      vf)))

(defparameter *vf-map* nil)

(defun search-previous-frame (vf id)
  (let* ((frames (vf-frames vf))
         (len (length frames)))
    (flet ((wrap (n)
             (if (minusp n)
                 (+ (1- len) n)
                 n)))
      (loop
        :for n := (wrap (1- id)) :then (wrap (1- n))
        :until (= n id)
        :do (unless (null (aref frames n))
              (return-from search-previous-frame (aref frames n)))))))

(defun search-next-frame (vf id)
  (let* ((frames (vf-frames vf))
         (len (length frames)))
    (flet ((wrap (n)
             (if (>= n len)
                 (- len n)
                 n)))
      (loop
        :for n := (wrap (1+ id)) :then (wrap (1+ n))
        :until (= n id)
        :do (unless (null (aref frames n))
              (return-from search-next-frame (aref frames n)))))))

(defun vf-require-update (vf)
  (cond ((vf-changed vf) t)
        ((not (= (display-width)
                 (vf-width vf)))
         t)
        ((not (= (display-height)
                 (vf-height vf)))
         t)))

(defmethod window-redraw ((window vf) force)
  (when (or force
            (loop :for k :being :each :hash-key :of *vf-map*
                  :using (hash-value vf)
                  :thereis (vf-require-update vf)))
    ;; draw button for frames
    (let* ((buffer (vf-header-buffer window))
           (p (buffer-point buffer))
           (charpos (point-charpos p)))
      (erase-buffer buffer)
      (loop
        :for %frame :across (vf-frames window)
        :unless (null %frame)
        :do (let ((focusp (eq %frame (vf-current window)))
                  (start-pos (point-charpos p)))
              (insert-button p
                             ;; virtual frame name on header
                             (if focusp
                                 (format nil "[#~a]* " (%frame-id %frame))
                                 (format nil "[#~a] "(%frame-id %frame)))
                             ;; set action when click
                             (let ((%frame %frame))
                               (lambda ()
                                 (setf (vf-current window) %frame)
                                 (setf (vf-changed window) t)))
                             :attribute (if focusp
                                            'fm-active-frame-name-attribute
                                            'fm-frame-name-attribute))
              ;; increment charpos
              (when focusp
                (let ((end-pos (point-charpos p)))
                  (unless (<= start-pos charpos (1- end-pos))
                    (setf charpos start-pos))))))
      ;; fill right margin
      (let ((margin-right (- (display-width) (point-column p))))
        (when (> margin-right 0)
          (insert-string p (make-string margin-right :initial-element #\space)
                         :attribute 'fm-background-attribute)))
      (line-offset p 0 charpos))
    ;; set all vf-changed to nil because of applying redraw
    (maphash (lambda (k vf)
               (declare (ignore k))
               (setf (vf-changed vf) nil))
             *vf-map*)
    (call-next-method)))

(defun frame-multiplexer-init ()
  (setf *vf-map* (make-hash-table))
  (loop
    :for impl :in (list (implementation))  ; for multi-frame support in the future...
    :do (let ((vf (make-vf impl (lem::get-frame impl))))
          (setf (gethash impl *vf-map*) vf))))

(defun frame-multiplexer-on ()
  (unless (variable-value 'frame-multiplexer :global)
    (frame-multiplexer-init)))

(defun frame-multiplexer-off ()
  (when (variable-value 'frame-multiplexer :global)
    (maphash (lambda (k v)
               (declare (ignore k))
               (delete-window v))
             *vf-map*)
    (setf *vf-map* nil)))

(define-editor-variable frame-multiplexer nil ""
  (lambda (value)
    (if value
        (frame-multiplexer-on)
        (frame-multiplexer-off))))

(define-command fm () ()
  (setf (variable-value 'frame-multiplexer :global)
        (not (variable-value 'frame-multiplexer :global))))

(define-key *global-keymap* "c-z c" 'fm-create)
(define-command fm-create () ()
  (block exit
    (let* ((vf (gethash (implementation) *vf-map*))
           (id (position-if #'null (vf-frames vf))))
      (when (null id)
        ;; ERROR: it's full of frames in virtual frame
        (return-from exit))
      (let* ((frame (lem::make-frame))
             (%frame (%make-frame id frame)))
        (setf (aref (vf-frames vf) id) %frame
              (vf-current vf) %frame))
      (setf (vf-changed vf) t))))

(define-key *global-keymap* "c-z d" 'fm-delete)
(define-command fm-delete () ()
  (block exit
    (let* ((vf (gethash (implementation) *vf-map*))
           (num (count-if-not #'null (vf-frames vf)))
           (id (position (vf-current vf) (vf-frames vf))))
      (when (= num 1)
        ;; ERROR: there is just one frame in virtual frame
        (return-from exit))
      (when (null id)
        ;; ERROR: something wrong...
        (return-from exit))
      (setf (aref (vf-frames vf) id) nil
            (vf-current vf) (search-previous-frame vf id))
      (setf (vf-changed vf) t))))

(define-key *global-keymap* "C-z p" 'fm-prev)
(define-command fm-prev () ()
  (block exit
    (let* ((vf (gethash (implementation) *vf-map*))
           (id (position (vf-current vf) (vf-frames vf))))
      (when (null id)
        ;; ERROR: something wrong...
        (return-from exit))
      (setf (vf-current vf) (search-previous-frame vf id))
      (setf (vf-changed vf) t))))

(define-key *global-keymap* "C-z n" 'fm-next)
(define-command fm-next () ()
  (block exit
    (let* ((vf (gethash (implementation) *vf-map*))
           (id (position (vf-current vf) (vf-frames vf))))
      (when (null id)
        ;; ERROR: something wrong...
        (return-from exit))
      (setf (vf-current vf) (search-next-frame vf id))
      (setf (vf-changed vf) t))))
