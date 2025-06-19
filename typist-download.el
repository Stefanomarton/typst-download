;;; typst-download.el --- Paste clipboard images in typst-ts-mode  -*- lexical-binding: t; -*-

;; Author:  Stefano Marton
;; Keywords: typst, images, clipboard, convenience
;; Package-Requires: ((emacs "28.1"))
;;
;; Install:  Save this file somewhere in `load-path` and
;;           (require 'typst-download)  ; or use use-package/straight/elpaca

(defgroup typst-download nil
  "Paste images from the clipboard and insert Typst markup."
  :group 'typst
  :prefix "typst-download-")

(defcustom typst-download-image-dir "images"
  "Directory (relative to the current .typ file) where pasted images are stored."
  :type 'string)

(defcustom typst-download-default-ext ".png"
  "File-name extension to use when saving clipboard images."
  :type 'string)

(require 'subr-x)                       ; for string-empty-p / string-trim

;; ---------------------------------------------------------------------
;; Default insertion behaviour *with interactive prompts*
;; ---------------------------------------------------------------------

(defun typst-download--interactive-insert (file)
  "Return a `#figure( … )` snippet for FILE, querying user for extras.

Empty answers fall back to:
  • width → \"50%\"
  • caption → omit the caption line
  • reference → omit the <fig:…> suffix"
  (let* ((w   (string-trim (read-from-minibuffer "Width [default 50%]: ")))
         (width (if (string-empty-p w) "50%" w))
         (caption (string-trim (read-from-minibuffer "Caption [optional]: ")))
         (ref     (string-trim (read-from-minibuffer "Reference [optional] fig: "))))
    (concat
     "#figure(\n"
     (format "    image(\"%s\", width: %s)%s\n"
             file width (if (string-empty-p caption) "" ","))
     (unless (string-empty-p caption)
       (format "    caption: [%s]\n" caption))
     ")\n"
     (unless (string-empty-p ref)
       (format " <fig:%s>" ref)))))

(defcustom typst-download-insert-fn
  #'typst-download--interactive-insert   ;; ← THIS IS NOW THE DEFAULT
  "Function that converts a saved image FILE (relative path) into
the Typst snippet inserted at point.  The default implementation
prompts for width, caption and figure reference as described in
`typst-download--interactive-insert'."
  :type 'function)

(defun typst-download--clipboard->file (file)
  "Save the current clipboard image to FILE.
  Tries `pngpaste` (macOS), `wl-paste` (Wayland) or `xclip` (X11)."
  (cond
   ((executable-find "pngpaste")
    (call-process "pngpaste" nil nil nil file))
   ((executable-find "wl-paste")
    (call-process-shell-command
     (format "wl-paste --type image/png > %s"
             (shell-quote-argument file))))
   ((executable-find "xclip")
    (call-process-shell-command
     (format "xclip -selection clipboard -t image/png -o > %s"
             (shell-quote-argument file))))
   (t (user-error "No clipboard utility found.  Install pngpaste, wl-clipboard or xclip"))))

;;;###autoload
(defun typst-download-clipboard (&optional name)
  "Grab an image from the clipboard, save it, and insert Typst markup.
  With \\[universal-argument] prompts for NAME (base file name)."
  (interactive
   (list (when current-prefix-arg
           (read-string "Image base-name (no extension): "))))
  (unless (and buffer-file-name (string-suffix-p ".typ" buffer-file-name t))
    (user-error "Not in a .typ file"))
  (let* ((base (or name (format-time-string "%Y%m%d%H%M%S_screenshot")))
         (dir  (expand-file-name typst-download-image-dir
                                 (file-name-directory buffer-file-name)))
         (file (expand-file-name (concat base typst-download-default-ext) dir)))
    (unless (file-directory-p dir)
      (make-directory dir t))
    (typst-download--clipboard->file file)
    (let ((rel (file-relative-name file (file-name-directory buffer-file-name))))
      (insert (funcall typst-download-insert-fn rel))
      (newline))
    (message "Saved image → %s" file)))

(provide 'typst-download)
;;; typst-download.el ends here
