;;; init-decorator.el --- frame decoration, fonts, theme -*- lexical-binding: t; -*-
;; `my/font-size', `my/font-families', `my/font-name', `my/font-available-p'
;; and `my/first-available-font' are defined in early-init.el, which has to run
;; before the initial frame is created.

(defvar my/deco nil
  "Symbol naming the frame-decorator function to apply to new frames.")

;; `my/fonts' used to embed the size in the family string ("... Nerd Font 12"),
;; which `find-font' cannot use -- it needs a bare :family in a `font-spec'.
;; Family and size are now separate: `my/font-families' + `my/font-size'.
(define-obsolete-variable-alias 'my/fonts 'my/font-families "2026-08")

(defun my/available-fonts ()
  "Installed subset of `my/font-families', in preference order."
  (let (found)
    (dolist (family my/font-families (nreverse found))
      (when (my/font-available-p family) (push family found)))))

(defun my/set-font (family &optional size)
  "Set the `default' face to FAMILY at SIZE everywhere.  Never signals.
Returns FAMILY on success, nil on failure."
  (condition-case err
      (progn
        ;; KEEP-SIZE nil, FRAMES t => all graphical frames + the default face
        ;; for future frames (frame.el:1445-1450).  The Customize side effect
        ;; is intentional: it is what propagates the font to new frames.
        (set-frame-font (my/font-name family size) nil t)
        family)
    (error (message "my/set-font: cannot use %S: %s"
                    family (error-message-string err))
           nil)))

(defun my/apply-font (&optional frame)
  "Apply the first installed family of `my/font-families' to FRAME.
Degrades to a message -- never an error -- if nothing is installed."
  (let ((frame (or frame (selected-frame))))
    (if-let* ((family (my/first-available-font nil frame)))
        (my/set-font family my/font-size)
      (when (display-graphic-p frame)
        (message "my/apply-font: none of %S installed; keeping Emacs default"
                 my/font-families))
      nil)))

(defun my/toggle-font (family &optional size)
  "Set the `default' font to FAMILY.
Interactively, complete over families that are actually installed;
with a prefix argument, also prompt for SIZE in points."
  (interactive
   (list (completing-read "Font family: "
                          (or (my/available-fonts) my/font-families)
                          nil t nil nil (face-attribute 'default :family))
         (and current-prefix-arg (read-number "Size (pt): " my/font-size))))
  (when size (setq my/font-size size))
  (when (my/set-font family my/font-size)
    (message "Font: %s" (my/font-name family))))


;; --- vterm ------------------------------------------------------------------
;; FiraCode in vterm terminal buffers -- tighter spacing suits terminal output.
(defvar my/vterm-font-families
  (append (when (eq system-type 'windows-nt) '("FiraCode NFM" "FiraCode NF"))
          '("FiraCode Nerd Font Mono" "FiraCode Nerd Font"))
  "Preferred families for vterm buffers; falls back to `my/font-families'.")

(defun my/vterm-set-font ()
  "Remap the `default' face in this vterm buffer to a tighter terminal font."
  (when-let* ((family (or (my/first-available-font my/vterm-font-families)
                          (my/first-available-font))))
    (face-remap-add-relative 'default :family family)))

;; Top level, NOT inside the decorator: under a daemon the decorator runs once
;; per new frame, so the old anonymous-lambda `add-hook' accumulated a
;; duplicate remap for every frame ever created.
(add-hook 'vterm-mode-hook #'my/vterm-set-font)


;; --- decorators -------------------------------------------------------------
(defun my/default-decorator (frame)
  (menu-bar-mode -1)
  (tool-bar-mode -1)
  (scroll-bar-mode -1)
  (setq visible-bell t)

  (line-number-mode -1)
  (display-line-numbers-mode -1)

  ;; Font and theme are each isolated: a font problem must never abort init
  ;; (it would take `after-init-hook' -- and with it all of Elpaca -- along).
  (when (display-graphic-p frame)
    (my/apply-font frame))

  (condition-case err
      (unless (memq 'modus-operandi-tinted custom-enabled-themes)
        (load-theme 'modus-operandi-tinted t))
    (error (message "my/default-decorator: theme failed: %s"
                    (error-message-string err)))))


(defun my/presentation-decorator (frame)
  (menu-bar-mode -1)
  (tool-bar-mode -1)
  (scroll-bar-mode -1)
  (display-line-numbers-mode -1)
  (setq visible-bell nil)
  (condition-case err
      (load-theme 'modus-vivendi t)
    (error (message "my/presentation-decorator: theme failed: %s"
                    (error-message-string err)))))


(defun init-my/decorator ()
  ;; For the built-in themes which cannot use `require'.
  (require-theme 'modus-themes) ; `require-theme' is ONLY for the built-in Modus themes
  (define-key global-map (kbd "<f5>") #'modus-themes-toggle)
  (setq my/deco 'my/default-decorator)

  (if (daemonp)
      ;; No graphic frame yet, so font resolution waits for one.
      (add-hook 'after-make-frame-functions my/deco)
    (funcall my/deco (selected-frame))))


(init-my/decorator)
