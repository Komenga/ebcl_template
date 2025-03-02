"""
Taskfile implementation of the image interface.
"""
import logging
import os
import sys

from pathlib import Path
from subprocess import PIPE, Popen
from time import sleep
from typing import Any, Optional

from util.proc_io import kill_process_tree
from .power_interface import PowerInterface


ON_POSIX = 'posix' in sys.builtin_module_names


class PowerQemu(PowerInterface):
    """
    Taskfile implementation of the image interface.
    """

    def __init__(self, shell="bash", qemu_cmd="task run_qemu"):
        self.process = None
        self.shell = shell
        self.qemu_cmd = qemu_cmd

    def power_on(self, image: Optional[str], cmd: Optional[str] = None) -> Any:
        """
        Run the image.
        """
        if self.process:
            logging.info(
                'Old shell session found. Killing old shell session...')
            kill_process_tree(self.process.pid)

        logging.info('Running shell %s...', self.shell)

        if not image:
            logging.error("No image given!")
            return None

        if not os.path.isfile(image):
            logging.error("Image file does not exist!")
            return None

        path = Path(image)

        cwd = path.parent.parent.absolute()

        self.process = Popen(self.shell, stdout=PIPE, stderr=PIPE, stdin=PIPE,
                             bufsize=1, close_fds=ON_POSIX, shell=True, encoding='utf-8',
                             cwd=cwd)

        sleep(0.2)

        qemu_cmd = self.qemu_cmd
        if cmd is not None:
            qemu_cmd = cmd

        logging.info('Using Power On command: %s', qemu_cmd)
        self.process.stdin.write(f'{qemu_cmd}\n')

        return self.process

    def power_off(self, cmd: Optional[str] = None):
        """
        Stop the image by "power-cut".
        """
        if self.process:
            if cmd is not None:
                logging.info('Power off kills the process, "%s" is not used.', cmd)
            kill_process_tree(self.process.pid)
