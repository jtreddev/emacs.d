;;; early-init.el --- pre-frame setup -*- lexical-binding: t; -*-

;; NOTE: do NOT enable `init-file-debug' / `debug-on-error' unconditionally.
;; In Emacs 30 `startup--load-user-init-file' wraps the load in `handler-bind'
;; when `init-file-debug' is t (startup.el:1119) -- and `handler-bind' does not
;; unwind, so the error still escapes -- while `debug-on-error' t disarms the
;; `condition-case-unless-debug' in the other branch (startup.el:1121).  Either
;; way ANY error in init propagates out of `command-line', `after-init-hook'
;; never runs (startup.el:1570), and `elpaca-process-queues' never fires: zero
;; packages get installed, silently.  Use `emacs --debug-init' for a backtrace,
;; or set EMACS_DEBUG_INIT in the environment.
(when (getenv "EMACS_DEBUG_INIT")
  (setq init-file-debug t
        debug-on-error t))

(setq package-enable-at-startup nil)

(push '(undecorated . t) default-frame-alist)

;; --- Fonts ------------------------------------------------------------------
;; Defined here rather than in init-decorator.el because the initial frame's
;; font must be chosen before `command-line' creates the frame, and early-init
;; is the only file that runs first.  init-decorator.el reuses all of it.

(defvar my/font-size 12
  "Point size for the `default' face.")

(defvar my/font-families
  (append
   ;; Windows GDI reports the *legacy* family name (OpenType name ID 1), which
   ;; Nerd Fonts v3 truncates to <= 31 characters:
   ;;   "JetBrainsMono Nerd Font Mono"  -> "JetBrainsMono NFM"
   ;;   "JetBrainsMono Nerd Font"       -> "JetBrainsMono NF"
   ;;   "JetBrainsMono Nerd Font Propo" -> "JetBrainsMono NFP"
   ;; fontconfig (Linux) reads name ID 16 and sees the long name, so BOTH
   ;; spellings must be candidates.  NFM (Nerd Font *Mono*) leads: its icons
   ;; are single-width, which keeps corfu margins and dired aligned.
   (when (eq system-type 'windows-nt)
     '("JetBrainsMono NFM" "JetBrainsMono NF" "JetBrainsMono NFP"
       "JetBrainsMonoNL NFM" "JetBrainsMonoNL NF"
       "FiraCode NFM" "Hack NFM" "CaskaydiaCove NFM" "MesloLGM NFM"))
   '("JetBrainsMono Nerd Font Mono" "JetBrainsMono Nerd Font"
     "FiraCode Nerd Font Mono" "FiraCode Nerd Font"
     "Hack Nerd Font Mono" "Hack Nerd Font"
     "CaskaydiaCove Nerd Font Mono" "MesloLGM Nerd Font"
     "UbuntuMono Nerd Font"
     ;; Non-patched fallbacks: no icons, but always readable.
     "JetBrains Mono" "Cascadia Mono" "DejaVu Sans Mono"
     "Consolas" "Courier New"))
  "Candidate families for the `default' face, most preferred first.
Cross-platform: Windows short names lead on Windows, long Nerd Font
names follow for Linux/macOS.")

(defun my/font-name (family &optional size)
  "Return a font-name string for FAMILY at SIZE (default `my/font-size', points)."
  (format "%s-%d" family (or size my/font-size)))

(defun my/font-available-p (family &optional frame)
  "Non-nil if FAMILY is installed and usable on FRAME.  Never signals.
Returns nil on a tty frame or before any graphic frame exists."
  (let ((frame (or frame (selected-frame))))
    (and (display-graphic-p frame)
         (ignore-errors (find-font (font-spec :family family) frame)))))

(defun my/first-available-font (&optional families frame)
  "First installed family in FAMILIES (default `my/font-families'), else nil."
  (catch 'found
    (dolist (family (or families my/font-families))
      (when (my/font-available-p family frame)
        (throw 'found family)))
    nil))

;; Set the font on the initial frame *before* it is created, otherwise the
;; first GUI frame is mapped with the tiny built-in default font/size and the
;; window manager keeps that small geometry even after the decorator runs.
;;
;; This one cannot be validated: no graphic frame exists yet, so `find-font'
;; has no display to query (early-init loads at startup.el:1375, window-system
;; init at :1416).  `my/font-families' is platform-ordered, so its car is the
;; correct spelling for this OS; `my/apply-font' confirms/refines it once a
;; frame exists.
(when (memq initial-window-system '(w32 ns pgtk x haiku))
  (push (cons 'font (my/font-name (car my/font-families))) default-frame-alist))

;; Don't let the early font/size change trigger a frame resize race.
(setq frame-inhibit-implied-resize t)
