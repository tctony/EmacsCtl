# EmacsCtl

A macos menu bar app which controls the state of emacs deamon process just like systemctl on linux.

First write your emacs pid to file.
```elisp
(unless (spacemacs/system-is-mswindows)
  (let ((pidfile (concat dotspacemacs-ignore-directory "emacs.pid"))
        (pid (number-to-string (emacs-pid))))

    (with-temp-file pidfile
      (message (format "write pid %s to %s" pid pidfile))
      (insert pid))

    (add-hook 'kill-emacs-hook
              `(lambda ()
                 (with-temp-file ',pidfile)
                  (insert "")))
    )
  )

(provide 'pidfile)
```

Then configure your pid file path and emacs path.

// TODO configure window img

Finally enjoy yourself!

// TODO menu img



