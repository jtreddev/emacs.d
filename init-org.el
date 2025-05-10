(setq org-agenda-files "~/../../OneDrive - Kimball International Inc/Org-Mode/agenda")

(global-set-key (kbd "C-c l") #'org-store-link)
(global-set-key (kbd "C-c a") #'org-agenda)
(global-set-key (kbd "C-c c") #'org-capture)


(setq org-agenda-custom-commands
    '(("x" agenda)
      ("y" agenda*)
      ("f" occur-tree "\\<FIXME\\>")))

(setq org-refile-targets '((org-agenda-files :maxlevel . 5))
      org-refile-use-outline-path 'file
      org-log-into-drawer t
      org-log-done 'time
      org-log-redeadline 'time
      org-log-reschedule 'time
      org-use-fast-todo-selection 'expert
      org-indent-mode t
      org-startup-indented t)
