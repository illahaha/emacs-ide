=====================================
Instructions for installing Emacs-IDE
=====================================

You just have to create the package and install it.

::

  ./build-package
  ./install-package

The package is installed in ~/.emacs.d/elpa/eide-<version> directory.

You must add the following lines in your ~/.emacs:

::

  (package-initialize)
  (eide-start)

NB:

- (package-initialize) might already be present and should not be added in that
  case.

- If you have installed several versions, the package with the higher version
  number will be loaded.

- If you're installing a development version, the package version number is not
  relevant.
