;;; init-eat-blink-ab.el --- A/B test eat's cursor-blink redraw strategy -*- lexical-binding: t; -*-

;; Background:
;;   eat's `eat--flip-cursor-blink-state' repaints on every cursor-blink tick.
;;   Upstream (akib/emacs-eat, unchanged since the first commit in 2022) uses
;;   `redraw-frame', which clears and repaints the ENTIRE frame each tick and
;;   carries the author's own note: "This is expensive, and some causes
;;   flickering.  Any better way?".  The lightweight alternative is
;;   `force-window-update', which marks only the eat window for incremental
;;   redisplay.  Upstream never adopted it; the patch lives in
;;   patches/eat-cursor-blink-force-window-update.patch.
;;
;;   Rather than edit the package source (which an elpaca rebuild would silently
;;   revert), we keep eat.el pristine and override the one function here, with a
;;   runtime switch so the two strategies can be A/B'd live by eye.
;;
;;   NOTE: This :override mirrors the upstream function body verbatim except for
;;   the redraw call.  eat froze this function in 2022, but if upstream ever
;;   changes `eat--flip-cursor-blink-state', re-sync the body below.

;; Forward declarations for eat's internal blink state (defined in eat.el),
;; to keep the byte-compiler quiet; bound at runtime in eat buffers.
(defvar eat--cursor-blink-mode)
(defvar eat--cursor-blink-state)
(defvar eat--cursor-blink-type)
(defvar eat-terminal)
(declare-function eat-term-size "eat" (terminal))
(declare-function eat-term-resize "eat" (terminal width height))
(declare-function eat-term-redisplay "eat" (terminal))

(defvar my/eat-blink-redraw-method 'force-window-update
  "Redraw strategy used by the eat cursor-blink override.
`redraw-frame'        -> A: upstream original, full-frame repaint.
`force-window-update' -> B: the fix, window-local incremental redisplay.
Default is B: A/B testing concluded `force-window-update' removes the
per-blink full-frame flicker seen while Claude Code runs.  Toggle live
with `M-x my/eat-blink-toggle'.")

(defun my/eat--flip-cursor-blink-state-ab ()
  "A/B `:override' for `eat--flip-cursor-blink-state'.
Identical to upstream except the redraw call is chosen at runtime by
`my/eat-blink-redraw-method'."
  (when (and (bound-and-true-p eat--cursor-blink-mode)
             (display-graphic-p))
    (setq-local cursor-type (if eat--cursor-blink-state
                                (caddr eat--cursor-blink-type)
                              (car eat--cursor-blink-type)))
    (setq eat--cursor-blink-state (not eat--cursor-blink-state))
    (when-let* ((window (get-buffer-window nil 'visible)))
      (if (eq my/eat-blink-redraw-method 'force-window-update)
          (force-window-update window)          ; B: the fix
        (redraw-frame (window-frame window)))))) ; A: upstream original

(with-eval-after-load 'eat
  (advice-add 'eat--flip-cursor-blink-state :override
              #'my/eat--flip-cursor-blink-state-ab))

(defun my/eat-blink-toggle ()
  "Flip the eat cursor-blink redraw strategy between A (original) and B (fix).
Takes effect on the next blink tick in any live eat buffer, so you can
watch the difference without restarting Emacs."
  (interactive)
  (setq my/eat-blink-redraw-method
        (if (eq my/eat-blink-redraw-method 'force-window-update)
            'redraw-frame
          'force-window-update))
  (message "eat blink redraw -> %s  [%s]"
           my/eat-blink-redraw-method
           (if (eq my/eat-blink-redraw-method 'force-window-update)
               "B: force-window-update (fix)"
             "A: redraw-frame (upstream original)")))

;;; ------------------------------------------------------------------------
;;; Force eat's child app to repaint after a transient layout change
;;;
;;; Symptom: open the consult/vertico minibuffer (or abort a command with C-g)
;;; and the eat (Claude Code) window is left with a blank gap at the bottom that
;;; never recovers --- only a manual window resize fixes it.
;;;
;;; Cause (diagnosed empirically, not a scroll/size bug --- the eat grid is
;;; already full height and matches the window): the transient shrink+regrow of
;;; the eat window nets to zero, so the child TUI is never sent an effective
;;; SIGWINCH and never repaints the rows it blanked for the smaller size.  Only
;;; a *real* resize event makes it redraw; a no-op resize-to-same-size does not.
;;;
;;; Fix: after layout changes settle, nudge each visible eat terminal one row
;;; smaller and --- after a short beat --- back, sending two genuine SIGWINCHes
;;; so the app repaints.  Debounced so rapid changes collapse to one nudge.

(defvar my/eat--refresh-timer nil
  "Pending debounce timer for `my/eat-refresh-terminals'.")

(defvar my/eat--refreshing nil
  "Non-nil while a nudge is in progress; reentrancy guard for the hooks.")

(defun my/eat--nudge (buf)
  "Send BUF's eat terminal a shrink+grow SIGWINCH pair so its app repaints."
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (when-let* ((eat-terminal)
                  (proc (get-buffer-process buf))
                  ((process-live-p proc))
                  ((get-buffer-window buf t))            ; only if displayed
                  (size (eat-term-size eat-terminal))
                  (w (car size))
                  (h (cdr size))
                  ((> h 1)))
        (set-process-window-size proc (1- h) w)          ; SIGWINCH #1: shrink
        (eat-term-resize eat-terminal w (1- h))
        (eat-term-redisplay eat-terminal)
        (run-at-time                                     ; beat, then restore
         0.05 nil
         (lambda ()
           (when (buffer-live-p buf)
             (with-current-buffer buf
               (when (and eat-terminal (process-live-p proc))
                 (set-process-window-size proc h w)      ; SIGWINCH #2: grow
                 (eat-term-resize eat-terminal w h)
                 (eat-term-redisplay eat-terminal))))))))))

(defun my/eat-refresh-terminals ()
  "Nudge every visible eat terminal to repaint.  See commentary above."
  (setq my/eat--refresh-timer nil)
  (let ((my/eat--refreshing t))
    (dolist (buf (buffer-list))
      (when (buffer-local-value 'eat-terminal buf)
        (my/eat--nudge buf)))))

(defun my/eat-schedule-refresh (&rest _)
  "Debounced trigger for `my/eat-refresh-terminals' (ignores any args)."
  (unless my/eat--refreshing
    (when (timerp my/eat--refresh-timer)
      (cancel-timer my/eat--refresh-timer))
    (setq my/eat--refresh-timer
          (run-at-time 0.1 nil #'my/eat-refresh-terminals))))

;; The reported triggers (consult/vertico minibuffer, C-g abort) are exactly
;; minibuffer exit, which fires only on close/quit --- much lighter than
;; `window-size-change-functions' (which fires on every redisplay size change
;; and would nudge after legitimate resizes too).  If a non-minibuffer transient
;; popup ever strands the terminal, add `window-configuration-change-hook' here.
(add-hook 'minibuffer-exit-hook #'my/eat-schedule-refresh)

(provide 'init-eat-blink-ab)
;;; init-eat-blink-ab.el ends here
