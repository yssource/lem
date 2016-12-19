(in-package :lem)

(export '(find-file
          read-file
          save-buffer
          changefile-name
          write-file
          insert-file
          save-some-buffers
          revert-buffer
          change-directory))

(defun expand-files* (filename)
  (setf filename (expand-file-name filename))
  (or (directory filename)
      (list filename)))

(define-key *global-keymap* (kbd "C-x C-f") 'find-file)
(define-command find-file (filename) ("FFind File: ")
  (check-switch-minibuffer-window)
  (when (pathnamep filename)
    (setf filename (namestring filename)))
  (dolist (pathname (expand-files* filename))
    (switch-to-buffer (find-file-buffer (namestring pathname))))
  t)

(define-key *global-keymap* (kbd "C-x C-r") 'read-file)
(define-command read-file (filename) ("FRead File: ")
  (check-switch-minibuffer-window)
  (when (pathnamep filename)
    (setf filename (namestring filename)))
  (dolist (pathname (expand-files* filename))
    (switch-to-buffer (find-file-buffer (namestring pathname))))
  t)

(define-key *global-keymap* (kbd "C-x C-s") 'save-buffer)
(define-command save-buffer () ()
  (let ((buffer (current-buffer)))
    (cond
      ((null (buffer-modified-p buffer))
       nil)
      ((not (buffer-have-file-p buffer))
       (message "No file name")
       nil)
      (t
       (save-buffer-internal)
       (message "Wrote ~A" (buffer-filename))))))

(define-key *global-keymap* (kbd "C-x C-w") 'write-file)
(define-command write-file (filename) ("FWrite File: ")
  (setf (buffer-%filename (current-buffer)) filename)
  (save-buffer-internal)
  (message "Wrote ~A" (buffer-filename)))

(define-key *global-keymap* (kbd "C-x C-i") 'insert-file)
(define-command insert-file (filename) ("fInsert file: ")
  (insert-file-contents (current-marker)
                        filename)
  t)

(define-key *global-keymap* (kbd "C-x s") 'save-some-buffers)
(define-command save-some-buffers (&optional save-silently-p) ("P")
  (check-switch-minibuffer-window)
  (save-excursion
    (dolist (buffer (buffer-list))
      (when (and (buffer-modified-p buffer)
                 (buffer-have-file-p buffer))
        (switch-to-buffer buffer nil)
        (when (or save-silently-p
                  (progn
                    (redraw-display)
                    (minibuf-y-or-n-p "Save file")))
          (save-buffer))))))

(define-command revert-buffer (does-not-ask-p) ("P")
  (when (and (or (buffer-modified-p (current-buffer))
                 (changed-disk-p (current-buffer)))
             (or does-not-ask-p
                 (minibuf-y-or-n-p (format nil "Revert buffer from file ~A" (buffer-filename)))))
    (with-buffer-read-only (current-buffer) nil
      (buffer-erase)
      (insert-file-contents (current-marker)
                            (buffer-filename))
      (buffer-unmark (current-buffer))
      (update-changed-disk-date (current-buffer))
      t)))

(define-command change-directory (directory)
    ((list (minibuf-read-file "change directory: " (buffer-directory))))
  (setf (buffer-directory) (expand-file-name directory))
  t)
