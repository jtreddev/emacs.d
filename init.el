(add-to-list 'load-path "~/site-lisp")
(setq my/packages '("elpaca" ;; Elpaca is best to be first as it deals with early loading and package management.
		    "cm" ;; Always load CM early so we may undo the 'damage'.
		    "vertico" "corfu" "cape" "consult" "marginalia" "embark" "magit"
		    "decorator"))

(mapcar (lambda (pkg)
	  (load-file (expand-file-name (concat "init-" pkg ".el") user-emacs-directory)))
	my/packages)

(fset 'yes-or-no-p 'y-or-n-p)

(use-package which-key :init (which-key-mode 1)
:ensure t :demand t)

(use-package request
  :ensure t :demand t
  :config
  (setq request-log-level 'blather))

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))

(init-my/decorator)
