#!/usr/bin/env python3
"""Configure independent consumers of LLVM build-tree and installed packages.

Run after generating both packages. No LLVM or consumer compilation is needed.
The real AddLLVM dependency wiring must work without defining LLVM-private
validation targets in either downstream project.
"""
import argparse
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-package', required=True, type=Path)
    parser.add_argument('--install-package', required=True, type=Path)
    parser.add_argument('--work-dir', required=True, type=Path)
    parser.add_argument('--cmake', default='cmake')
    args = parser.parse_args()
    source = args.work_dir / 'consumer'
    source.mkdir(parents=True, exist_ok=True)
    (source / 'main.cpp').write_text('int main() { return 0; }\n')
    (source / 'CMakeLists.txt').write_text('''cmake_minimum_required(VERSION 3.20)
project(RuntimeLayoutPackageConsumer LANGUAGES C CXX)
find_package(LLVM REQUIRED CONFIG NO_DEFAULT_PATH)
list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")
include(AddLLVM)
add_executable(control EXCLUDE_FROM_ALL main.cpp)
add_llvm_executable(package_consumer EXCLUDE_FROM_ALL main.cpp)
message(STATUS "RUNTIME_LAYOUT_PACKAGE_CONSUMER_REACHED")
''')
    for kind, package in [('build', args.build_package),
                          ('install', args.install_package)]:
        subprocess.run([args.cmake, '-S', str(source), '-B',
                        str(args.work_dir / kind), '-G', 'Ninja',
                        '-DLLVM_DIR=' + str(package.resolve())], check=True)
        print('RUNTIME_LAYOUT_PACKAGE_CONSUMER_OK: ' + kind, flush=True)


if __name__ == '__main__':
    main()
