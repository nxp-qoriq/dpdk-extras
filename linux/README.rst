Building Out-of-Tree Kernel Drivers for Linux
=============================================

Prerequisites
-------------

The system must have relevant Linux kernel headers or source code installed.


Build
-----

To build ``igb_uio`` driver, simply run ``make`` command
inside the ``igb_uio`` directory:

.. code-block:: console

   cd igb_uio
   make

If compiling against a specific kernel source directory is required,
it is possible to specify the kernel source directory
using the ``KSRC`` variable:

.. code-block:: console

   make KSRC=/path/to/custom/kernel/source


Load
----

.. note::

   These commands are to be run as ``root`` user.

The ``igb_uio`` driver requires the UIO driver to be loaded beforehand.
If ``uio`` is not built-in:

.. code-block:: console

   modprobe uio

Then the out-of-tree driver may be loaded.

.. code-block:: console

   insmod igb_uio.ko


Clean
-----

To clean the build directory, the following command can be run:

.. code-block:: console

   make clean
