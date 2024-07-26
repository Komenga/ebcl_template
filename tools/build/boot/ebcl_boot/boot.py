#!/usr/bin/env python
""" EBcL boot generator. """
import argparse
import logging
import os
import queue
import shutil
import tempfile

from pathlib import Path

from ebcl.apt import Apt, Package
from ebcl.deb import extract_archive
from ebcl.fake import Fake
import yaml


class BootGenerator:
    """ EBcL boot generator. """
    # config file
    config: Path
    # config values
    packages: list[str]
    files: list[dict[str, str]]
    scripts: list[str]
    arch: str
    apt_repos: list[dict[str, str | list[str]]]
    archive_name: str
    target_dir: str
    archive_path: str
    download_deps: bool
    # apt repos
    apts: list[Apt]
    # fakeroot helper
    fake: Fake

    def __init__(self, config_file: str):
        """ Parse the yaml config file.

        Args:
            config_file (Path): Path to the yaml config file.
        """
        with open(config_file, 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)

        self.config = Path(config_file)

        self.packages = config.get('packages', [])
        self.files = config.get('files', [])
        self.scripts = config.get('scripts', [])
        self.arch = config.get('arch', 'arm64')
        self.archive_name = config.get('archive_name', 'boot.tar')
        self.apt_repos = config.get('apt_repos', None)
        self.download_deps = config.get('download_deps', True)

        self.apts = []
        if self.apt_repos is None:
            self.apts.append(
                Apt(
                    url='https://linux.elektrobit.com/eb-corbos-linux/1.2',
                    distro='ebcl',
                    components=['prod', 'dev'],
                    arch=self.arch
                )
            )
        else:
            for repo in self.apt_repos:
                self.apts.append(
                    Apt(
                        url=repo['apt_repo'],
                        distro=repo['distro'],
                        components=repo['components'],
                        arch=self.arch
                    )
                )

        self.fake = Fake()

    def download_deb_packages(self, package_dir: str):
        """ Download all needed deb packages. """
        pq: queue.Queue[str] = queue.Queue(maxsize=len(self.packages) * 100)
        local_packages: dict[str, str] = {}

        for p in self.packages:
            logging.info('Adding package %s to download queue.', p)
            pq.put_nowait(p)

        while not pq.empty():
            name = pq.get_nowait()

            for apt in self.apts:
                package = apt.find_package(name)
                if package is not None:
                    break

            if package is None:
                logging.error('The package %s was not found!', name)
                exit(1)

            if name not in local_packages:
                # Download and extract deb
                logging.info('Downloading package %s...', package.name)
                deb_file = package.download(location=package_dir)

                local_packages[name] = deb_file
                logging.info('Deb file: %s', deb_file)

                extract_archive(deb_file, location=package_dir)
                # Remove downloaded package
                os.remove(deb_file)

                # Add deps to queue
                for p in package.get_depends():
                    if p not in local_packages:
                        logging.info(
                            'Adding package %s to download queue. Len: %d', p, pq.qsize())
                        pq.put_nowait(p)

        return package_dir

    def copy_files(self, package_dir: str):
        """ Copy files to be used. """
        for entry in self.files:
            dst = Path(self.target_dir)
            if entry['destination']:
                dst = dst / entry['destination']

            mode: str = entry.get('mode', "600")

            src = os.path.abspath(os.path.join(package_dir, entry['source']))
            src_parent = Path(os.path.dirname(src))
            pattern = os.path.basename(entry['source'])
            files = src_parent.glob(pattern)

            for file in files:
                logging.info('Copying file %s to %s', src, dst)

                if file.is_file():
                    self.fake.run(f'mkdir -p {dst}')
                    self.fake.run(f'cp {src} {dst}')
                    self.fake.run(f'chmod {mode} {dst}')
                    uid = entry.get('uid', '0')
                    gid = entry.get('uid', '0')
                    self.fake.run(f'chown {uid}:{gid} {dst}')
                elif file.is_dir():
                    self.fake.run(f'mkdir -p {dst}')
                    self.fake.run(f'cp -R {src} {dst}')
                    self.fake.run(f'chmod {mode} {dst}')
                    uid = entry.get('uid', '0')
                    gid = entry.get('uid', '0')
                    self.fake.run(f'chown -R {uid}:{gid} {dst}')
                else:
                    logging.warning('Source %s does not exist', src)

    def run_scripts(self):
        """ Run scripts. """
        for script in self.scripts:
            script = os.path.abspath(os.path.join(self.config.parent, script))

            if not os.path.isfile(script):
                logging.error('Script %s not found!', script)
                continue

            logging.info('Running script: %s', script)
            shutil.copyfile(script, self.target_dir)

            self.fake.run_chroot(
                f'./{os.path.basename(script)}', self.target_dir)

    def create_boot(self, output_path: str) -> None:
        """ Create the boot.tar.  """
        self.target_dir = tempfile.mkdtemp()
        logging.info('Target directory: %s', self.target_dir)

        package_dir = tempfile.mkdtemp()
        logging.info('Package directory: %s', package_dir)

        self.download_deb_packages(package_dir)

        # Copy files and directories specified in the files
        self.copy_files(package_dir)

        # Remove package temporary folder
        shutil.rmtree(package_dir)

        self.run_scripts()

        self.fake.run('tar -cvf boot.tar .', cwd=self.target_dir)
        archive = f'{self.target_dir}/boot.tar'
        archive_out = f'{output_path}/{self.archive_name}'
        self.fake.run(f'mv {archive} {archive_out}')

        # delete temporary folder
        # shutil.rmtree(self.target_dir)


def main() -> None:
    """ Main entrypoint of EBcL boot generator. """
    logging.basicConfig(level=logging.INFO)

    parser = argparse.ArgumentParser(
        description='Create the content of the boot partiton as boot.tar.')
    parser.add_argument('config_file', type=str,
                        help='Path to the YAML configuration file')
    parser.add_argument('output', type=str,
                        help='Path to the output directory')

    args = parser.parse_args()

    # Read configuration
    generator = BootGenerator(args.config_file)

    # Create the boot.tar
    generator.create_boot(args.output)


if __name__ == '__main__':
    main()
