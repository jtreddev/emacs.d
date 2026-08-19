(add-to-list 'load-path (expand-file-name "site-lisp" user-emacs-directory))

;; --- Keep generated files out of the config dir -----------------------------
;; Route Emacs' transient/generated state (backups, auto-saves, lock files,
;; caches, history) into a per-user directory under /tmp so the config dir
;; stays clean and nothing regeneratable is ever committed.
;; NOTE: /tmp is cleared on reboot, so only ephemeral/cheaply-regenerated state
;; goes here. Package build dirs (elpa/, elpaca/, eln-cache/) stay on disk to
;; avoid recompiling on every boot; they are handled by .gitignore instead.
(defvar my/tmp-dir
  (expand-file-name (format "emacs%d/" (user-uid)) temporary-file-directory)
  "Base directory under /tmp for Emacs generated files.")

(defun my/tmp (name)
  "Return an absolute path for NAME inside `my/tmp-dir', creating parents."
  (let ((path (expand-file-name name my/tmp-dir)))
    (make-directory (file-name-directory path) t)
    path))

(dolist (dir '("backups/" "auto-saves/" "auto-save-list/"))
  (make-directory (expand-file-name dir my/tmp-dir) t))

;; Backups (foo~)
(setq backup-directory-alist `((".*" . ,(expand-file-name "backups/" my/tmp-dir)))
      backup-by-copying t
      version-control t
      delete-old-versions t
      kept-new-versions 6
      kept-old-versions 2)

;; Auto-saves (#foo#)
(setq auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-saves/" my/tmp-dir) t))
      auto-save-list-file-prefix
      (expand-file-name "auto-save-list/.saves-" my/tmp-dir))

;; Lock files (.#foo)  (Emacs 28+)
(when (boundp 'lock-file-name-transforms)
  (setq lock-file-name-transforms
        `((".*" ,(expand-file-name "lock/" my/tmp-dir) t))))

;; Persistent state files that are safe to regenerate.
(setq recentf-save-file (my/tmp "recentf")
      savehist-file (my/tmp "savehist")
      save-place-file (my/tmp "places")
      bookmark-default-file (my/tmp "bookmarks")
      project-list-file (my/tmp "projects")
      eshell-directory-name (my/tmp "eshell/")
      url-configuration-directory (my/tmp "url/")
      url-cache-directory (my/tmp "url/cache/"))
(with-eval-after-load 'request
  (setq request-storage-directory (my/tmp "request/")))

;; Transient (magit et al.) history/state.
(with-eval-after-load 'transient
  (setq transient-history-file (my/tmp "transient/history.el")
        transient-levels-file  (my/tmp "transient/levels.el")
        transient-values-file  (my/tmp "transient/values.el")))

;; Tramp persistence and its auto-saves.
(with-eval-after-load 'tramp
  (setq tramp-persistency-file-name (my/tmp "tramp/persistency.el")
        tramp-auto-save-directory   (my/tmp "tramp/auto-saves/")))
;; ----------------------------------------------------------------------------

(setq my/packages '("elpaca" ;; Elpaca is best to be first as it deals with early loading and package management.
		    "vertico"
		    "corfu" "cape" "consult" "marginalia" "embark" "magit" "rust" "ai"
		    "tramp" "container" "decorator"
		    ))

(mapcar (lambda (pkg)
	  (load-file (expand-file-name (concat "init-" pkg ".el") user-emacs-directory)))
	my/packages)

(fset 'yes-or-no-p 'y-or-n-p)

(use-package which-key :init (which-key-mode 1)
  :ensure t :demand t)

(use-package request
  :ensure t :demand t)

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file 'noerror)


(global-auto-revert-mode 1)

;; Also auto-revert non-file buffers like Dired
(setq global-auto-revert-non-file-buffers t)
;; Quieter — suppress the "Reverting buffer..." messages
(setq auto-revert-verbose nil)
