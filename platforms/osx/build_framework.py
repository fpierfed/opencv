#!/usr/bin/env python
"""
The script builds OpenCV.framework for OSX.
The built framework is universal, it can be used to build app and run it on
either 32-bit or 64-bit OSX.

Usage:
    ./build_framework.py <outputdir>

By cmake conventions (and especially if you work with OpenCV repository),
the output dir should not be a subdirectory of OpenCV source tree.

Script will create <outputdir>, if it's missing, and a few its subdirectories:

    <outputdir>
        build/
            MacOSX-i386/
               [cmake-generated build tree for an i386 OSX device target]
            MacOSX-x86_64/
               [cmake-generated build tree for an x86_64 OSX device target]
        opencv2.framework/
            [the framework content]

The script should handle minor OpenCV updates efficiently
- it does not recompile the library from scratch each time.
However, opencv2.framework directory is erased and recreated on each run.
"""
import glob
import os
import os.path
import shutil
import sys
try:
    from shlex import quote
except ImportError:
    import re

    _find_unsafe = re.compile(r'[^\w@%+=:,./-]').search

    def quote(s):
        """Return a shell-escaped version of the string *s*."""
        if not s:
            return "''"
        if _find_unsafe(s) is None:
            return s

        # use single quotes, and put single quotes into double quotes
        # the string $'b is then quoted as '$'"'"'b'
        return "'" + s.replace("'", "'\"'\"'") + "'"


def build_opencv(srcroot, buildroot, target, arch):
    "builds OpenCV for device or simulator"

    builddir = os.path.join(buildroot, target + '-' + arch)
    if not os.path.isdir(builddir):
        os.makedirs(builddir)
    currdir = os.getcwd()
    os.chdir(builddir)
    # for some reason, if you do not specify CMAKE_BUILD_TYPE, it puts libs to
    # "RELEASE" rather than "Release"
    cmakeargs = ('-GXcode ' +
                 '-DAPPLE_FRAMEWORK=ON ' +
                 '-DCMAKE_BUILD_TYPE=Release ' +
                 '-DBUILD_SHARED_LIBS=OFF ' +
                 '-DBUILD_DOCS=OFF ' +
                 '-DBUILD_EXAMPLES=OFF ' +
                 '-DBUILD_TESTS=ON ' +
                 '-DBUILD_PERF_TESTS=OFF ' +
                 '-DBUILD_opencv_apps=OFF ' +
                 '-DBUILD_opencv_world=ON ' +
                 '-DBUILD_opencv_matlab=OFF ' +
                 '-DWITH_CUDA=OFF ' +
                 '-DWITH_FFMPEG=OFF ' +
                 '-DWITH_TIFF=ON -DBUILD_TIFF=ON ' +
                 '-DWITH_JASPER=ON -DBUILD_JASPER=ON ' +
                 '-DWITH_WEBP=ON -DBUILD_WEBP=ON ' +
                 '-DWITH_OPENEXR=ON -DBUILD_OPENEXR=ON ' +
                 '-DWITH_IPP=OFF -DWITH_IPP_A=OFF ' +
                 '-DCMAKE_C_FLAGS="-Wno-implicit-function-declaration" ' +
                 '-DCMAKE_INSTALL_PREFIX=install')
    # if cmake cache exists, just rerun cmake to update OpenCV.xproj if
    # necessary
    cmd = 'cmake %s %s' % (cmakeargs, srcroot)
    if os.path.isfile(os.path.join(builddir, 'CMakeCache.txt')):
        cmd = 'cmake %s .' % (cmakeargs,)
    err = os.system(cmd)
    if err:
        print('Command "%s" failed with exit code %d' % (cmd, err))
        return err

    wlibs = (os.path.join(builddir, 'modules', 'world', 'UninstalledProducts',
                          'libopencv_world.a'),
             os.path.join(builddir, 'lib', 'Release', 'libopencv_world.a'))
    for wlib in wlibs:
        if os.path.isfile(wlib):
            os.remove(wlib)

    cmds = ('xcodebuild -parallelizeTargets ARCHS="%s" -sdk %s ' +
            '-configuration Release -target ALL_BUILD',
            'xcodebuild ARCHS="%s" -sdk %s ' +
            '-configuration Release -target install install')
    for cmd in cmds:
        fullcmd = cmd % (arch, target.lower())
        err = os.system(fullcmd)
        if err:
            print('Command "%s" failed with exit code %d' % (fullcmd, err))
            return err
    os.chdir(currdir)
    return 0


def put_framework_together(srcroot, dstroot):
    "constructs the framework directory after all the targets are built"

    # find the list of targets (basically, ["iPhoneOS", "iPhoneSimulator"])
    targetlist = glob.glob(os.path.join(dstroot, 'build', '*'))
    targetlist = [os.path.basename(t) for t in targetlist]

    # set the current dir to the dst root
    framework_dir = os.path.join(dstroot, 'opencv2.framework')
    if os.path.isdir(framework_dir):
        shutil.rmtree(framework_dir)
    os.makedirs(framework_dir)
    os.chdir(framework_dir)

    # form the directory tree
    dstdir = os.path.join('Versions', 'A')
    os.makedirs(os.path.join(dstdir, 'Resources'))

    tdir0 = os.path.join(dstroot, 'build', targetlist[0])
    # copy headers
    shutil.copytree(os.path.join(tdir0, 'install', 'include', 'opencv2'),
                    os.path.join(dstdir, 'Headers'))

    # make universal static lib
    wlist = ' '.join([quote(os.path.join(dstroot, 'build', t, 'lib', 'Release',
                                         'libopencv_world.a'))
                      for t in targetlist])
    os.system('lipo -create %s -o "%s"' %
              (wlist, os.path.join(dstdir, 'opencv2')))

    # copy Info.plist
    shutil.copyfile(os.path.join(tdir0, 'osx', 'Info.plist'),
                    os.path.join(dstdir, 'Resources', 'Info.plist'))

    # make symbolic links
    os.symlink('A', os.path.join('Versions', 'Current'))
    os.symlink(os.path.join('Versions', 'Current', 'Headers'), 'Headers')
    os.symlink(os.path.join('Versions', 'Current', 'Resources'), 'Resources')
    os.symlink(os.path.join('Versions', 'Current', 'opencv2'), 'opencv2')
    return


def build_framework(srcroot, dstroot):
    "main function to do all the work"
    targets = [('MacOSX', 'x86_64'), ('MacOSX', 'i386')]
    for (target, arch) in targets:
        err = build_opencv(srcroot=srcroot, target=target, arch=arch,
                           buildroot=os.path.join(dstroot, 'build'))
        if err:
            return err
    put_framework_together(srcroot, dstroot)
    return 0


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print('Usage:\n\t./build_framework.py <outputdir>\n\n')
        sys.exit(0)

    here = os.path.dirname(os.path.abspath(__file__))
    build_framework(srcroot=os.path.join(here, '..', '..'),
                    dstroot=os.path.abspath(sys.argv[1]))
