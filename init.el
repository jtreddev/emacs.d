(add-to-list 'load-path (expand-file-name "site-lisp" user-emacs-directory))

;; --- Keep generated files out of the config dir -----------------------------
;; Route Emacs' transient/generated state (backups, auto-saves, lock files,
;; caches, history) into a per-user directory under /tmp so the config dir
;; stays clean and nothing regeneratable is ever committed.
;; NOTE: /tmp is cleared on reboot, so only ephemeral/cheaply-regenerated state
;; goes here. Package build dirs (elpa/, elpaca/, eln-cache/) stay on disk to
;; avoid recompiling on every boot; they are handled by .gitignore instead.
(defvar my/tmp-dir
  ;; `user-uid' returns -1 for a non-elevated Windows user, which would give a
  ;; literal "emacs-1/"; fall back to the login name there.  Note that on
  ;; Windows `temporary-file-directory' is %LOCALAPPDATA%\Temp\, which is NOT
  ;; cleared on reboot -- the "ephemeral" premise above holds only on Unix.
  (expand-file-name (if (natnump (user-uid))
                        (format "emacs%d/" (user-uid))
                      (format "emacs-%s/" (user-login-name)))
                    temporary-file-directory)
  "Base directory for Emacs generated files under `temporary-file-directory'.")

(defun my/tmp (name)
  "Return an absolute path for NAME inside `my/tmp-dir', creating parents."
  (let ((path (expand-file-name name my/tmp-dir)))
    (make-directory (file-name-directory path) t)
    path))

(dolist (dir '("backups/" "auto-saves/" "auto-save-list/"))
  (make-directory (expand-file-name dir my/tmp-dir) t))

;; Backups (foo~)
(setq backup-directory-alist `((".*" . ,(expand-file-name "backups/" my/tmp-dir)))
      backup-by-copying nil
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
		    "cm"
		    "vertico"
		    "corfu" "cape" "consult" "marginalia" "embark" "magit" "rust" "ai"
		    "tramp" "container" "decorator"
		    ))

;; --- The user's real home ---------------------------------------------------
;; On the Configura box Emacs is launched by cm-tools.exe, which sets
;; HOME=c:\CetDev\gnu so Cygwin has a POSIX-shaped home.  `~' therefore expands
;; to c:/CetDev/gnu/, NOT to C:/Users/<name>: this config is only found at all
;; because c:\CetDev\gnu\.emacs loads init.el and c:\CetDev\gnu\.emacs.d is a
;; symlink to the real one.  Anything that means "the user's profile directory"
;; must go through this variable rather than `~', or it silently resolves inside
;; the CetDev tree.
(defvar my/home
  (file-name-as-directory
   (or (and (eq system-type 'windows-nt) (getenv "USERPROFILE"))
       (expand-file-name "~")))
  "The user's profile directory, which is not necessarily `~'.")

(defun my/home-file (name)
  "Expand NAME against `my/home'."
  (expand-file-name name my/home))

;; --- Make user-installed tools visible --------------------------------------
;; cm-tools.exe also composes PATH itself, from the machine PATH plus a stale
;; copy of the user PATH.  Entries added to the user PATH afterwards --
;; ~/.local/bin (claude) and WinGet's shim directory (rg, fd) -- never reach
;; `exec-path', and neither restarting Emacs nor logging out brings them back.
;; `executable-find' then returns nil and every caller that resolves a binary at
;; startup silently falls back, which is how claude-code-ide ends up reporting
;; "CLI not available" for a CLI that is installed and working.
;;
;; Both variables matter: `exec-path' is what `executable-find' and
;; `call-process' search, while PATH is what child processes inherit.
(dolist (dir (list (my/home-file ".local/bin")
                   (when (eq system-type 'windows-nt)
                     (expand-file-name "Microsoft/WinGet/Links"
                                       (or (getenv "LOCALAPPDATA")
                                           (my/home-file "AppData/Local"))))))
  (when (and dir (file-directory-p dir))
    (add-to-list 'exec-path dir)
    ;; PATH must use native separators or child shells mis-parse it.
    (let ((native (convert-standard-filename dir)))
      (unless (member native (split-string (or (getenv "PATH") "") path-separator))
        (setenv "PATH" (concat native path-separator (getenv "PATH")))))))

(defun my/load-init-module (pkg)
  "Load init-PKG.el, reporting -- but never propagating -- any error.
Deliberately plain `condition-case', not `condition-case-unless-debug': a
single broken module must never escape to `command-line' and thereby skip
`after-init-hook' (and with it `elpaca-process-queues')."
  (let ((file (expand-file-name (format "init-%s.el" pkg) user-emacs-directory)))
    (condition-case err
        (if (file-readable-p file)
            (load file nil 'nomessage)
          (warn "init: missing module %s" file))
      (error (warn "init: error loading %s: %s" file (error-message-string err))))))

(dolist (pkg my/packages) (my/load-init-module pkg))

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
