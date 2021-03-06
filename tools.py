#!/usr/bin/env python3
import os

import click

from utils.package import PackageResourceGenerator, PackageMetainfoModifier


@click.group()
def cli():
    pass


@cli.group(help="Library related operations.")
def lib():
    pass


@cli.group(help="Resource related operations.")
def res():
    pass


@lib.command(help="Change version number of all files in lib folder.")
@click.option('--src', default='lib', help='path of lib folder')
def bump_version(src):
    abs_src = os.path.abspath(src)
    pmm = PackageMetainfoModifier()
    pmm.bump_version(abs_src)


@lib.command(help="Update metainfo of each file.")
@click.option('--src', default='lib', help='path of lib folder')
@click.option('--ignore-cmd', multiple=True, help='package name to skip executable commands check(can use multiple times)')
def update_metainfo(src, ignore_cmd):
    ignore_cmd = list(ignore_cmd)
    ignore_cmd.append("global-variables")
    abs_src = os.path.abspath(src)
    pmm = PackageMetainfoModifier()
    pmm.update_metainfo(abs_src, ignore_cmd)


@res.command(help="Generate all resources from script in library.")
@click.option('--src', default='lib', help='source path of folder to parse')
@click.option('--dst', default='res', help='destination path of parsed information folder')
@click.option('--exclude', multiple=True, help='package name to exclude(can use multiple times)')
def generate(src, dst, exclude):
    abs_src = os.path.abspath(src)
    abs_dst = os.path.abspath(dst)
    prg = PackageResourceGenerator()
    prg.parse_folder(abs_src)
    prg.generate_all(abs_dst, exclude_list=exclude)


if __name__ == "__main__":
    cli()
