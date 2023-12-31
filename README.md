# EmacsCtl

### Features
- Use menu on mac status bar to control(start, restart, new window...) emacs deamon process just like systemctl does on linux.
- Activate emacs window with global shortcut.
- Support `org-protocol` scheme so you don't need to create an applescript app to do that.
- Support edit captured content when using `org-roam-protocol`.

### Install

- Latest app can be downloaded from [Releases](https://github.com/tctony/EmacsCtl/releases) page.
- Or you can clone this project and build your own.

### How to use

- First write your emacs pid to file.

    For spacemacs user, just use following code:
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

- Second configure your pid file path and emacs path.

    ![](./assets/setting.png)

    At least, you should set `Pid File Path` and `Emacs Binary Directory`.

    Also, you can set a shortcut to activate window window.

- Finally control your emacs from status bar menu.

    ![](./assets/menu.png)

