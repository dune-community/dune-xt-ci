#!/usr/bin/env python3
"""
Update docker images and templated scripts in dune-xt-*

Usage:
  update_test_dockers.py [options] MODULE_NAME

Options:
   -h --help       Show this message.
   -v --verbose    Set logging level to debug.
"""

from docopt import docopt
from os import path
import importlib
import os
import contextlib
import subprocess
import sys
import logging
import time
import six
import re
try:
    import docker
except ImportError:
    print('missing module: pip install docker')
    sys.exit(1)
from docker.utils.json_stream import json_stream

TAG_MATRIX = {
    'debian-unstable_gcc_full': {
        'cc': 'gcc',
        'cxx': 'g++',
        'deletes': "",
        'base': 'debian-unstable'
    },
    'debian_gcc_full': {
        'cc': 'gcc',
        'cxx': 'g++',
        'deletes': "",
        'base': 'debian'
    },
    'debian_clang_full': {
        'cc': 'clang',
        'cxx': 'clang++',
        'deletes': "",
        'base': 'debian'
    },
}
#'arch_gcc_full': {'cc': 'gcc', 'cxx': 'g++', 'deletes': "", 'base': 'arch'},}


@contextlib.contextmanager
def remember_cwd(dirname):
    curdir = os.getcwd()
    try:
        os.chdir(dirname)
        yield curdir
    finally:
        os.chdir(curdir)


class Timer(object):

    def __init__(self, section, log):
        self._section = section
        self._start = 0
        self._log = log
        self.time_func = time.time

    def start(self):
        self.dt = -1
        self._start = self.time_func()

    def stop(self):
        self.dt = self.time_func() - self._start

    def __enter__(self):
        self.start()

    def __exit__(self, type_, value, traceback):
        self.stop()
        self._log('Execution of {} took {} (s)'.format(self._section, self.dt))


def _docker_build(client, **kwargs):
    resp = client.api.build(**kwargs)
    if isinstance(resp, six.string_types):
        return client.images.get(resp)
    last_event = None
    image_id = None
    output = []
    for chunk in json_stream(resp):
        if 'error' in chunk:
            msg = chunk['error'] + '\n' + ''.join(output)
            raise docker.errors.BuildError(msg, resp)
        if 'stream' in chunk:
            output.append(chunk['stream'])
            match = re.search(r'(^Successfully built |sha256:)([0-9a-f]+)$', chunk['stream'])
            if match:
                image_id = match.group(2)
        last_event = chunk
    if image_id:
        return client.images.get(image_id)
    raise docker.errors.BuildError(last_event or 'Unknown', resp)


def _cmd(cmd, logger):
    logger.debug(' '.join(cmd))
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, universal_newlines=True)
        logger.debug(out)
    except subprocess.CalledProcessError as cp:
        logger.error(cp.output)
        logger.error('Failed: {}'.format(' '.join(cmd)))
        logger.error('Make sure the pushers group has write access to this repo on hub.cocker.com!')
        raise cp


def _build_base(scriptdir, distro, cc, cxx, commit, refname, superurl):
    client = docker.from_env(version='auto')
    base_postfix = '{}_{}'.format(distro, cc)
    slug_postfix = 'base_{}'.format(base_postfix)
    logger = logging.getLogger('{}'.format(slug_postfix))
    dockerdir = path.join(scriptdir, 'shared_base')
    dockerfile = path.join(dockerdir, 'Dockerfile')
    repo = 'dunecommunity/dune-xt-docker_{}'.format(slug_postfix)
    with Timer('docker build ', logger.info):
        buildargs = {'COMMIT': commit, 'CC': cc, 'CXX': cxx, 'SUPERURL': superurl, 'BASE': distro}
        img = _docker_build(
            client, rm=False, buildargs=buildargs, pull=True, tag='{}:{}'.format(repo, commit), path=dockerdir)
        img.tag(repo, refname)
    with Timer('docker push {}:{}|{}'.format(repo, refname, commit), logger.info):
        client.images.push(repo, tag=refname)
        client.images.push(repo, tag=commit)
    return img


def _build_combination(tag_matrix, dockerdir, module, commit, refname):
    client = docker.from_env(version='auto')
    imgs = []
    for tag, settings in tag_matrix.items():
        cc = settings['cc']
        cxx = settings['cxx']
        vars = importlib.import_module(module)
        tmp_dir = path.join(path.dirname(path.abspath(__file__)), module, tag)
        logger = logging.getLogger('{} - {}'.format(module, tag))
        repo = 'dunecommunity/{}-testing_{}'.format(module, tag)

        with Timer('docker build ', logger.info):
            buildargs = {
                'COMMIT': commit,
                'CC': cc,
                'project_name': module,
                'modules_to_delete': vars.modules_to_delete,
                'BASE': settings['base']
            }
            img = _docker_build(
                client, rm=False, buildargs=buildargs, pull=True, tag='{}:{}'.format(repo, commit), path=dockerdir)
            img.tag(repo, refname)
        with Timer('docker push {}:{}|{}'.format(repo, refname, commit), logger.info):
            client.images.push(repo, tag=refname)
            client.images.push(repo, tag=commit)
        imgs.append(img)
    return imgs


def _get_superurl(superdir):
    superurl = os.environ.get('CI_REPOSITORY_URL', None)
    if superurl:
        return superurl
    cmd = ['git', 'remote', 'get-url', 'origin']
    return subprocess.check_output(cmd, universal_newlines=True)


def _get_ci_setup():
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], universal_newlines=True).strip()
    azure_commit = os.environ.get('Build.SourceVersion', None)
    gitlab_commit = os.environ.get('CI_COMMIT_SHA', None)
    commit = azure_commit or gitlab_commit or head

    azure_refname = os.environ.get('Build.SourceBranchName', None)
    gitlab_refname = os.environ.get('CI_COMMIT_REF_NAME', None)

    refname = azure_refname or gitlab_refname or 'master'
    return commit, refname.replace('/', '_')

    
if __name__ == '__main__':
    arguments = docopt(__doc__)
    level = logging.DEBUG if arguments['--verbose'] else logging.INFO
    logging.basicConfig(level=level)
    scriptdir = path.dirname(path.abspath(__file__))
    superdir = path.join(scriptdir, '..', '..', '..')
    superurl = _get_superurl(superdir)

    commit, refname = _get_ci_setup()
    all_compilers = {(f['base'], f['cc'], f['cxx']) for f in TAG_MATRIX.values()}

    module = arguments['MODULE_NAME']

    if module == 'BASE':
        for base, cc, cxx in all_compilers:
            _build_base(scriptdir, base, cc, cxx, commit, refname, superurl)
    else:
        module_dir = os.path.join(superdir, module)
        _build_combination(
            tag_matrix=TAG_MATRIX,
            dockerdir=os.path.join(scriptdir, 'individual_base'),
            module=module,
            commit=commit,
            refname=refname)
